require "test_helper"
require_relative "../support/steam_sign_in"

class HubGrandInventoryPanelTest < ActionDispatch::IntegrationTest
  include SteamSignIn

  setup do
    freeze_time
    @player = accounts_players(:player)
  end

  def other(**attributes) = Accounts::Player.create!({ steam_id: "76561197960800001", persona_name: "Explorer" }.merge(attributes))

  def discover_latest(player)
    game_first_discoveries(:common_card_one).update_columns(player_id: player.id, discovered_at: 12.minutes.ago)
  end

  def inventory = Game::GrandInventory.new(seasons: :all)

  def latest_card = I18n.with_locale(:fr) { inventory.latest_discovery.card }

  def show_hub
    sign_in(@player)
    get home_path(locale: :fr)
    assert_response :success
  end

  test "the panel opens the hub's side column, before the weekly mission: the count, the gauge, and the see-more link outside its frame" do
    discover_latest(other)

    show_hub

    found, total = inventory.found_count, inventory.total
    assert_select ".hub__aside > section.grand-inventory-panel:first-child + #community-goal"
    assert_select "section.grand-inventory-panel[aria-labelledby=grand-inventory-panel-title]" do
      assert_select ".panel.grand-inventory-panel__frame h2#grand-inventory-panel-title.hub-section-title", "Le Grand Inventaire"
      assert_select ".grand-inventory-panel__count[aria-hidden=true]", "#{found} / #{total}"
      assert_select ".visually-hidden", I18n.t("pages.home.grand_inventory.spoken", count: found, found:, total:, locale: :fr)
      assert_select "progress.set-row__bar[value=?][max=?][aria-hidden=true]", found.to_s, total.to_s
      assert_select "a[href=?]", grand_inventory_path(locale: :fr), 1
      assert_select ".panel a.button--link", false
      assert_select ".card", false
      assert_select "[style]", false
    end
    assert_select "section.grand-inventory-panel > p.grand-inventory-panel__open a.button--link[href=?]", grand_inventory_path(locale: :fr), "Voir le Grand Inventaire"
  end

  test "the latest discovery by a public player names the card and links the player, with how long ago" do
    explorer = other
    discover_latest(explorer)
    card = latest_card

    show_hub

    assert_select ".grand-inventory-panel__latest", "Dernière découverte : #{card.title}, par Explorer, il y a 12 min"
    assert_select ".grand-inventory-panel__latest a[href=?]", card_season_path(slug: card.id, number: card.season_number, locale: :fr), card.title
    assert_select ".grand-inventory-panel__latest a.player-name--linked[href=?]", brother_path(token: explorer.token, locale: :fr), "Explorer"
    assert_select ".grand-inventory-panel__empty", false
  end

  test "a latest discoverer since banned reads as the anonymous name, without a profile link" do
    discover_latest(accounts_players(:banned))

    show_hub

    assert_select ".grand-inventory-panel__latest .player-name--anonymous", "Un joueur anonyme"
    assert_select ".grand-inventory-panel__latest a.player-name", false
  end

  %i[friends_only private].each do |visibility|
    test "a #{visibility} latest discoverer the viewer may not see is named without a link" do
      discover_latest(other(visibility:))

      show_hub

      assert_select ".grand-inventory-panel__latest span.player-name", "Explorer"
      assert_select ".grand-inventory-panel__latest a.player-name", false
    end
  end

  test "with nothing discovered yet the panel keeps its shape: a zero count and the empty line" do
    Game::FirstDiscovery.delete_all

    show_hub

    total = inventory.total
    assert_select ".grand-inventory-panel__count", "0 / #{total}"
    assert_select "progress.set-row__bar[value='0'][max=?]", [ total, 1 ].max.to_s
    assert_select ".grand-inventory-panel__empty", "Aucune carte découverte pour l'instant."
    assert_select ".grand-inventory-panel__latest", false
  end
end
