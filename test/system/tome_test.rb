require "application_system_test_case"
require_relative "../support/catalog_seeds"

# A tome opened from the library's shelf (CAP-6, story 4.2): a player sees
# their cards face up and the missing ones named; a visitor sees every slot
# empty; on a phone the tome stands alone; a large set draws its art only
# near the viewport.
class TomeTest < ApplicationSystemTestCase
  include CatalogSeeds

  setup do
    OmniAuth.config.test_mode = true
  end

  teardown do
    OmniAuth.config.mock_auth.delete(:steam)
    OmniAuth.config.test_mode = false
  end

  def members(season, key)
    set = Catalog::Set.find_by!(season_id: season.id, key:)
    Catalog::SetMembership.where(set_id: set.id).order(:position, :id).pluck(:card_season_id)
  end

  def sign_in(player)
    OmniAuth.config.mock_auth[:steam] = OmniAuth::AuthHash.new(provider: "steam", uid: "https://steamcommunity.com/openid/id/#{player.steam_id}")
    visit home_path(locale: :en)
    click_steam_sign_in
    assert_signed_in
  end

  test "a player opens a tome from the shelf: their cards face up, the missing ones named" do
    season = publish_sets_draft
    player = accounts_players(:player)
    owned = members(season, "action-1").first(3)
    owned.each_with_index { |id, index| Game::Holding.create!(player_id: player.id, card_season_id: id, quantity: index == 1 ? 2 : 1) }
    sign_in(player)

    within(".hub-menu") { click_on "Collection" }
    click_on "Action · Tome 1"

    assert_selector "h1", text: "Action · Tome 1 · 2011–2015"
    assert_selector ".library__aside .tome[aria-current=page]", text: "Action · Tome 1"
    assert_selector ".open-tome__progress", text: "3 / 25"
    assert_selector ".open-tome__slots > li", count: 25
    assert_selector ".open-tome__slots .card--face", count: 3
    assert_selector ".open-tome__copies", count: 1, text: "×2"
    assert_selector ".slot", count: 22
    assert_selector ".slot", match: :first, text: "Missing card"
    # An empty slot is a small card's size.
    assert_equal [ 160, 240 ], page.evaluate_script("(() => { const r = document.querySelector('.slot').getBoundingClientRect(); return [ r.width, r.height ] })()")
    assert_no_selector ".library__back"
    take_screenshot

    click_on "Action · Tome 2"
    assert_selector "h1", text: "Action · Tome 2 · 2015"
    assert_selector ".open-tome__progress", text: "0 / 25"

    click_on "Bridge"
    assert_current_path home_path(locale: :en)
  end

  test "a visitor sees every slot empty" do
    season = publish_sets_draft
    Game::Holding.create!(player_id: accounts_players(:player).id, card_season_id: members(season, "p").first, quantity: 1)

    visit library_path(locale: :fr, kind: "publisher")
    find(".shelf a.tome .tome__name", exact_text: "P").click

    assert_selector "h1", text: "P"
    assert_selector ".open-tome__progress", text: "0 / 5"
    assert_selector ".slot", count: 5
    assert_no_selector ".open-tome__slots .card"
  end

  test "on a phone the tome stands alone, two slots to a row, with a way back to the shelf" do
    season = publish_sets_draft
    long = "The Long Chronicles of the Amethyst Archive and the Keys Its Keepers Lost at Sea"
    Catalog::CardText.where(card_id: Catalog::CardSeason.find(members(season, "action-1").first).card_id, locale: "en").update_all(title: long)
    page.driver.browser.manage.window.resize_to(390, 844)
    visit library_set_path(locale: :en, kind: "tome", key: "action-1")

    assert_selector ".slot", count: 25
    assert_no_selector ".library__aside"
    tops = page.evaluate_script("[...document.querySelectorAll('.open-tome__slots > li')].slice(0, 3).map((slot) => slot.getBoundingClientRect().top)")
    assert_equal tops[0], tops[1]
    assert_operator tops[2], :>, tops[0]
    # A long title keeps to two lines, its full text kept.
    title = find(".slot__title", match: :first)
    assert_equal long, title.text(:all)
    line = page.evaluate_script("parseFloat(getComputedStyle(document.querySelector('.slot__title')).lineHeight)")
    assert_in_delta 2 * line, title.evaluate_script("this.getBoundingClientRect().height"), 1
    assert page.evaluate_script("document.documentElement.scrollWidth <= window.innerWidth"), "the page should not scroll sideways"
    take_screenshot

    click_on "Back to the shelf"
    assert_current_path library_path(locale: :en, kind: "tome")
    assert_selector ".shelf .tome", count: 4
  ensure
    page.driver.browser.manage.window.resize_to(*SCREEN_SIZE)
  end

  test "a publisher set of 300 cards draws its art only near the viewport" do
    season = seed_card_seasons(distinct_scores(300), publishers: Array.new(300, "Big"))
    assert Catalog::PublishSeason.new.call(number: season.number).success?
    player = accounts_players(:player)
    Game::Holding.insert_all!(members(season.reload, "big").map { |card_season_id| { player_id: player.id, card_season_id:, quantity: 1 } })
    sign_in(player)

    visit library_set_path(locale: :en, kind: "publisher", key: "big")

    assert_selector ".open-tome__slots .card--face", count: 300
    # The first cards are drawn (or fail, the test images being unreachable);
    # those far below are not even started.
    assert_selector ".open-tome__slots > li:first-child .card__art[data-art]", visible: :all
    started = page.all(".open-tome__slots .card__art[data-art]", visible: :all).size
    assert_operator started, :<, 100
    assert_no_selector ".open-tome__slots > li:last-child .card__art[data-art]", visible: :all

    page.execute_script("window.scrollTo(0, document.body.scrollHeight)")
    assert_selector ".open-tome__slots > li:last-child .card__art[data-art]", visible: :all
  end
end
