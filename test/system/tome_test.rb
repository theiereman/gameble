require "application_system_test_case"
require_relative "../support/catalog_seeds"

# One set in the collection (CAP-6, story 10.1): its missing slots keep a
# medium card's size and a long title to three lines; between 720 and
# 1179px the sets are a strip above the grid; a large set's grid comes sixty
# cards to a page, and draws its art only near the viewport.
class TomeTest < ApplicationSystemTestCase
  include CatalogSeeds

  setup do
    OmniAuth.config.test_mode = true
  end

  teardown do
    OmniAuth.config.mock_auth.delete(:steam)
    OmniAuth.config.test_mode = false
    page.driver.browser.manage.window.resize_to(*SCREEN_SIZE)
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

  def assert_no_sideways_scroll
    assert page.evaluate_script("document.documentElement.scrollWidth <= window.innerWidth"), "the page should not scroll sideways"
  end

  test "a missing slot is a medium card's size, hatched, its long title kept to three lines" do
    season = publish_sets_draft
    long = "The Long Chronicles of the Amethyst Archive and the Keys Its Keepers Lost at Sea"
    Catalog::CardText.where(card_id: Catalog::CardSeason.find(members(season, "action-1").first).card_id, locale: "en").update_all(title: long)

    visit library_set_path(locale: :en, kind: "tome", key: "action-1")

    assert_selector ".missing-slot", count: 25
    assert_equal [ 160, 240 ], page.evaluate_script("(() => { const r = document.querySelector('.missing-slot').getBoundingClientRect(); return [ r.width, r.height ] })()")
    title = find(".missing-slot__title", match: :first)
    assert_equal long, title.text(:all).strip
    line = page.evaluate_script("parseFloat(getComputedStyle(document.querySelector('.missing-slot__title')).lineHeight)")
    assert_in_delta 3 * line, title.evaluate_script("this.getBoundingClientRect().height"), 1
    assert_selector ".missing-slot svg.missing-slot__icon"
  end

  test "between 720 and 1179px the sets are a strip of 184px rows above the grid, the RAPPORT hidden" do
    publish_sets_draft
    page.driver.browser.manage.window.resize_to(900, 900)

    visit library_set_path(locale: :en, kind: "tome", key: "action-1")

    widths = page.evaluate_script("[...document.querySelectorAll('.collection-sets__list .set-row')].map((row) => Math.round(row.getBoundingClientRect().width))")
    assert_equal [ 184 ] * 5, widths
    tops = page.evaluate_script("[...document.querySelectorAll('.collection-sets__list .set-row')].map((row) => Math.round(row.getBoundingClientRect().top))")
    assert_equal 1, tops.uniq.size
    assert_operator page.evaluate_script("document.querySelector('.collection-grid').getBoundingClientRect().top"), :>, tops.first
    assert_no_selector ".report--panel, .report--fold, .collection-sets__kicker", visible: true
    assert_no_sideways_scroll
    take_screenshot
  end

  test "a publisher set of 300 cards comes sixty to a page and draws its art only near the viewport" do
    season = seed_card_seasons(distinct_scores(300), publishers: Array.new(300, "Big"))
    assert Catalog::PublishSeason.new.call(number: season.number).success?
    player = accounts_players(:player)
    Game::Holding.insert_all!(members(season.reload, "big").map { |card_season_id| { player_id: player.id, card_season_id:, quantity: 1 } })
    sign_in(player)

    visit library_set_path(locale: :en, kind: "publisher", key: "big")

    assert_selector ".collection-grid .card.card--m", count: 60
    # The first cards are drawn (or fail, the test images being unreachable);
    # those far below are not even started.
    assert_selector ".collection-grid > li:first-child .card__art[data-art]", visible: :all, wait: 10
    assert_no_selector ".collection-grid > li:last-child .card__art[data-art]", visible: :all

    page.execute_script("window.scrollTo(0, document.body.scrollHeight)")
    assert_selector ".collection-grid > li:last-child .card__art[data-art]", visible: :all, wait: 10

    find(".collection-pages a[rel=next]").click
    assert_current_path library_set_path(locale: :en, kind: "publisher", key: "big", page: 2)
    assert_selector ".collection-grid .card.card--m", count: 60
  end
end
