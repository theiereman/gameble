require "application_system_test_case"
require_relative "../support/catalog_seeds"
require_relative "../support/game_packs"

# A card's detail (CAP-7, story 4.3), opened from a tome's owned face, from
# an empty slot by a visitor, and from an opened pack's faces; on a phone the
# face above its fields.
class CardDetailTest < ApplicationSystemTestCase
  include CatalogSeeds
  include GamePacks

  setup do
    OmniAuth.config.test_mode = true
  end

  teardown do
    OmniAuth.config.mock_auth.delete(:steam)
    OmniAuth.config.test_mode = false
  end

  def sign_in(player)
    OmniAuth.config.mock_auth[:steam] = OmniAuth::AuthHash.new(provider: "steam", uid: "https://steamcommunity.com/openid/id/#{player.steam_id}")
    visit home_path(locale: :en)
    click_steam_sign_in
    assert_signed_in
  end

  def members(season, key)
    set = Catalog::Set.find_by!(season_id: season.id, key:)
    Catalog::SetMembership.where(set_id: set.id).order(:position, :id).pluck(:card_season_id)
  end

  test "a player opens an owned card from a tome: every field, their copies, the Steam link, its sets back to the tome" do
    season = publish_sets_draft
    player = accounts_players(:player)
    id = members(season, "action-1").first
    card = Catalog::CardSeason.find(id).card
    Catalog::CardText.where(card_id: card.id, locale: "en").update_all(short_description: "A seed of a game.")
    Game::Holding.create!(player_id: player.id, card_season_id: id, quantity: 2)
    sign_in(player)

    visit library_set_path(locale: :en, kind: "tome", key: "action-1")
    find(".open-tome__slots a.card-link", match: :first).click

    assert_current_path "/en/cards/#{card.slug}/seasons/#{season.number}"
    assert_selector ".card-detail h1", text: "Seed 0"
    assert_selector ".card-detail__face .card.card--xl"
    assert_selector ".card-detail__description", text: "A seed of a game."
    assert_selector ".card-detail__copies", text: "You hold 2 copies"
    assert_selector ".card-detail__notice", text: "This game and its image belong to their respective owners. gameble is not affiliated with Valve or Steam."
    link = find(".card-detail__store a", text: /\ASee it on the Steam store\z/i)
    assert_equal [ card.store_url, "_blank" ], [ link[:href], link[:target] ]
    take_screenshot

    click_on "Action · Tome 1"
    assert_selector "h1", text: "Action · Tome 1 · 2011–2015"
  end

  test "a visitor clicks an empty slot and reads the card's detail" do
    season = publish_sets_draft
    card = Catalog::CardSeason.find(members(season, "p").first).card

    visit library_set_path(locale: :fr, kind: "publisher", key: "p")
    find(".open-tome__slots a.card-link .slot", match: :first).click

    assert_current_path "/fr/cards/#{card.slug}/seasons/#{season.number}"
    assert_selector ".card-detail h1", text: card.texts.find_by!(locale: "fr").title
    assert_selector ".card-detail__fields dt", text: "Rareté"
    assert_no_selector ".card-detail__copies"
    assert_selector ".card-detail__store a[href$='l=french']"
  end

  test "an opened pack's faces lead to their cards" do
    player = accounts_players(:player)
    pack = create_pack(player, cards: fixture_tier_ids, opened_at: 1.minute.ago)
    sign_in(player)

    visit pack_path(pack.token, locale: :en)
    assert_selector ".pack-result__card a.card-link .card.card--m", count: 5
    find(".pack-result__card:nth-child(4) a.card-link").click

    assert_current_path "/en/cards/portal/seasons/1"
    assert_selector ".card-detail h1", text: "Portal"
    assert_selector ".card-detail__description", text: "A puzzle game of portals."
    assert_selector ".card-detail__sets a", text: "Valve"
  end

  test "the links to a card take the keyboard focus with a visible outline" do
    player = accounts_players(:player)
    pack = create_pack(player, cards: fixture_tier_ids, opened_at: 1.minute.ago)
    sign_in(player)

    visit pack_path(pack.token, locale: :en)
    link = find(".pack-result__card:first-child a.card-link")
    link.execute_script("this.focus()")

    assert_equal "Tin Soldier, Common, season 1", link["aria-label"]
    assert_equal "inline-block", link.evaluate_script("getComputedStyle(this).display")
    assert_not_equal "none", link.evaluate_script("getComputedStyle(this).outlineStyle")
  end

  test "on a phone the face stands above its fields, without sideways scroll" do
    page.driver.browser.manage.window.resize_to(390, 844)

    visit card_path(locale: :en, slug: "portal")

    face = page.evaluate_script("document.querySelector('.card-detail__face').getBoundingClientRect().bottom")
    body = page.evaluate_script("document.querySelector('.card-detail__body').getBoundingClientRect().top")
    assert_operator body, :>=, face
    assert page.evaluate_script("document.documentElement.scrollWidth <= window.innerWidth"), "the page should not scroll sideways"
    take_screenshot
  ensure
    page.driver.browser.manage.window.resize_to(*SCREEN_SIZE)
  end
end
