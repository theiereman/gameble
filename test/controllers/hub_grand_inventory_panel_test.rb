require "test_helper"
require_relative "../support/steam_sign_in"
require_relative "../support/supporters"

class HubGrandInventoryPanelTest < ActionDispatch::IntegrationTest
  include SteamSignIn
  include Supporters

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

  test "the panel opens the hub's side column, before the weekly mission: its title leads to the screen, then the count and the gauge" do
    discover_latest(other)

    show_hub

    found, total = inventory.found_count, inventory.total
    assert_select ".hub__aside > section.grand-inventory-panel:first-child + #community-goal"
    assert_select "section.panel.grand-inventory-panel.hub-linked[aria-labelledby=grand-inventory-panel-title]" do
      assert_select "h2#grand-inventory-panel-title.hub-section-title a.hub-linked__link[href=?]", grand_inventory_path(locale: :fr), "Le Grand Inventaire"
      assert_select ".grand-inventory-panel__count[aria-hidden=true]", "#{found} / #{total}"
      assert_select ".visually-hidden", I18n.t("pages.home.grand_inventory.spoken", count: found, found:, total:, locale: :fr)
      assert_select ".gauge[aria-hidden=true] .gauge__segment--lit", GaugeComponent.lit(found, total)
      assert_select "a", 1
      assert_select ".card", false
      assert_select "[style]", false
    end
    assert_select ".grand-inventory-panel__open", false
  end

  test "the latest discovery by a public player shows the game's art, its title, the player unlinked and how long ago" do
    discover_latest(other)
    card = latest_card

    show_hub

    assert_select ".grand-inventory-panel__latest" do
      assert_select "img.grand-inventory-panel__thumb[src=?][alt='']", card.image_url
      assert_select ".visually-hidden", "Dernière découverte :"
      assert_select ".grand-inventory-panel__game", card.title
      assert_select ".grand-inventory-panel__by", "par Explorer"
      assert_select "time.grand-inventory-panel__age", "il y a 12 min"
      assert_select "a", false
    end
    assert_select ".grand-inventory-panel__empty", false
  end

  test "a latest discoverer since banned reads as the anonymous name" do
    discover_latest(accounts_players(:banned))

    show_hub

    assert_select ".grand-inventory-panel__by .player-name--anonymous", "Un joueur anonyme"
  end

  %i[friends_only private].each do |visibility|
    test "a #{visibility} latest discoverer is named, as on every Grand Inventaire line" do
      discover_latest(other(visibility:))

      show_hub

      assert_select ".grand-inventory-panel__by span.player-name", "Explorer"
    end
  end

  test "with nothing discovered yet the panel keeps its shape: a zero count, an unlit gauge and the empty line" do
    Game::FirstDiscovery.delete_all

    show_hub

    total = inventory.total
    assert_select ".grand-inventory-panel__count", "0 / #{total}"
    assert_select ".grand-inventory-panel .gauge__segment--lit", false
    assert_select ".grand-inventory-panel__empty", "Aucune carte découverte pour l'instant."
    assert_select ".grand-inventory-panel__latest", false
  end

  test "the latest pioneer carries the VIP badge after their name when a supporter, none otherwise" do
    explorer = other
    discover_latest(explorer)

    show_hub
    assert_select ".grand-inventory-panel__by .supporter-badge", 0

    grant_supporter(explorer)
    show_hub
    assert_select ".grand-inventory-panel__by .player-name-group span.player-name + .supporter-badge--compact", "VIP"
  end
end
