require "test_helper"
require_relative "../support/steam_sign_in"

# Le Grand Inventaire, open without an account: the fixture season's five
# cards, each first found by the banned player long ago.
class GrandInventoriesControllerTest < ActionDispatch::IntegrationTest
  include SteamSignIn

  setup do
    @player = accounts_players(:player)
    @player.update!(persona_name: "Hugo")
  end

  def pioneer(card_season, player, at: Time.current)
    game_first_discoveries(card_season).update!(player_id: player.id, discovered_at: at)
  end

  def slot_labels = css_select("#collection-slots .card-link").map { it["aria-label"] }

  test "a visitor reads the whole screen: the count, the rarities, the pace, the sets, every card under its pioneer, and the way to sign in" do
    get grand_inventory_path(locale: :en)

    assert_response :success
    assert_select "h1.visually-hidden", "The Great Inventory"
    assert_select "[role=group][aria-label='Great Inventory seasons'] button[aria-pressed=true]", "All seasons"
    assert_select "[role=group] button[aria-pressed=false]", "Current season"
    assert_select ".grand-inventory__found", "5"
    assert_select ".grand-inventory__gauge[role=img][aria-label=?]", "5 cards discovered of 5"
    assert_select "a.grand-inventory__rarity--epic[aria-label=?][href=?]", "Epic: 1 discovered of 1, see these cards",
      grand_inventory_path(locale: :en, rarity: [ "epic" ], anchor: "grand-inventory-cards")
    assert_select ".grand-inventory__pace", /The Brotherhood has discovered everything\./
    assert_select ".grand-inventory__label", /Fully discovered · 1|1 set fully discovered/
    assert_select "a.grand-inventory__set-row[href=?]", brotherhood_set_path(locale: :en, kind: "studio", key: "valve"), minimum: 1
    assert_select ".grand-inventory__set-done", "Discovered"
    assert_equal 5, slot_labels.size
    assert_includes slot_labels, "Portal, Valve, 2007, Epic, discovered by anonymous"
    assert_select ".grand-inventory-slot__pioneer", text: "anonymous", count: 5
    assert_select ".grand-inventory-slot__badge", false
    assert_select "input[name='state[]'][value=mine]", false
    assert_select "input[name='state[]'][value=missing]"
    assert_select ".grand-inventory__visitor", /Join the Brotherhood to discover the missing cards\./
    assert_select "nav.grand-inventory__tabs .tabs__tab--current[aria-current=page]", "Cards"
  end

  test "a player's own discoveries read Vous and carry the VOUS badge, first in the grid; MES DÉCOUVERTES keeps them" do
    pioneer(:rare_card_one, @player)
    sign_in(@player)

    get grand_inventory_path(locale: :en)

    assert_equal "Blue Depths, 2014, Rare, discovered by you", slot_labels.first
    assert_select "#collection-slots li:first-child .grand-inventory-slot__badge", "YOU"
    assert_select "#collection-slots li:first-child .grand-inventory-slot__pioneer", "You"
    assert_select ".grand-inventory__visitor", false
    assert_select ".grand-inventory__pace a", "Blue Depths"

    get grand_inventory_path(locale: :en, state: %w[mine])
    assert_equal [ "Blue Depths, 2014, Rare, discovered by you" ], slot_labels
  end

  test "SAISON EN COURS is kept in the address; a card nobody found is a card to discover, listed after the found ones" do
    game_first_discoveries(:legendary_card_one).destroy!

    get grand_inventory_path(locale: :en, seasons: "current")

    assert_select "[role=group] button[aria-pressed=true]", "Current season"
    assert_select ".grand-inventory__found", "4"
    assert_select "[data-grand-inventory-status]", "Current season: 4 cards discovered of 5"
    assert_equal "Golden Crown, 1998, Legendary, to discover", slot_labels.last
    assert_select "#collection-slots li:last-child .card--not-owned"
    assert_select "#collection-slots li:last-child .grand-inventory-slot__pioneer", "To discover"
    assert_select "input[type=hidden][name=seasons][value=current]"

    get grand_inventory_path(locale: :en, seasons: "current", state: %w[missing])
    assert_equal [ "Golden Crown, 1998, Legendary, to discover" ], slot_labels
  end

  test "with nothing discovered, the count reads 0 and the pace line gives the empty line" do
    Game::FirstDiscovery.delete_all

    get grand_inventory_path(locale: :fr)

    assert_select ".grand-inventory__found", "0"
    assert_select ".grand-inventory__pace", "Aucune carte découverte pour l'instant."
    assert_select ".grand-inventory__label", "Aucun set entièrement découvert"
    assert_select "#collection-slots .card--not-owned", 5
  end

  test "a friends-only pioneer is named without a link for a visitor" do
    @player.update!(visibility: :friends_only)
    pioneer(:portal_one, @player)

    get grand_inventory_path(locale: :en)

    assert_select ".grand-inventory__pace .player-name", "Hugo"
    assert_select ".grand-inventory__pace a.player-name", false
  end

  test "the phone tab chosen is kept in the address and marked current" do
    get grand_inventory_path(locale: :en, view: "sets")

    assert_select "nav.grand-inventory__tabs .tabs__tab--current", "Sets"
    assert_select "nav.grand-inventory__tabs a.tabs__tab[href=?]", grand_inventory_path(locale: :en)
    assert_select ".grand-inventory__views--sets"
  end

  test "a card opened from the grid walks the grid and comes back to the Grand Inventaire" do
    pioneer(:rare_card_one, @player)
    context = { seasons: "current" }
    detail = ->(name) { card_season_path(locale: :en, slug: catalog_cards(name).slug, number: 1, inventory: context) }

    get detail.(:rare_card)

    back = css_select(".top-bar__phone-back").sole
    assert_equal [ grand_inventory_path(locale: :en, seasons: "current"), "Great Inventory" ], [ back["href"], back.text.squish ]
    assert_select "a[href=?]", detail.(:common_card)
  end
end
