require "application_system_test_case"
require_relative "../support/custom_sets"
require_relative "../support/game_sets"
require_relative "../support/holdings"
require_relative "../support/steam_sign_in"

# Hugo aims at Blue Depths through one custom set and at Green Hills through
# another, and holds the Soldier and two Portals. His friends hold, as
# duplicates, the cards he misses; the tests play two and three of them
# through the Trades screen.
class TradeSuggestionsJourneyTest < ApplicationSystemTestCase
  include CustomSets
  include GameSets
  include Holdings
  include SteamSignIn

  setup do
    @hugo = accounts_players(:player)
    @lea = accounts_players(:moderator)
    @max = accounts_players(:administrator)
    @hugo.update!(persona_name: "Hugo")
    @lea.update!(persona_name: "Lea")
    @max.update!(persona_name: "Max")
    [ @lea, @max ].each { befriend(@hugo, it) }
    @soldier = catalog_card_seasons(:common_card_one).id
    @hills = catalog_card_seasons(:uncommon_card_one).id
    @depths = catalog_card_seasons(:rare_card_one).id
    @portal = catalog_card_seasons(:portal_one).id
    @crown = catalog_card_seasons(:legendary_card_one).id
    hold(@hugo, @soldier)
    hold(@hugo, @portal, 2)
    custom_goal(@hugo, "Hugo's depths", [ @soldier, @depths ])
    custom_goal(@hugo, "Hugo's hills", [ @soldier, @hills ])
  end

  def befriend(first, second)
    low, high = [ first.id, second.id ].minmax
    Game::Friendship.create!(low_player_id: low, high_player_id: high)
  end

  def friend_of_hugo(name, steam_id)
    friend = Accounts::Player.create!(steam_id:, persona_name: name)
    befriend(@hugo, friend)
    friend
  end

  def custom_goal(player, name, card_season_ids)
    padded = card_season_ids + unheld_cards([ Game::CustomSet::GAMES.min - card_season_ids.size, 0 ].max)
    card_ids = Catalog::CardSeason.where(id: padded).pluck(:card_id)
    Game::AddGoal.new.call(player:, custom_set: create_custom_set(player, name:, card_ids:).token).value!
  end

  def game_set_goal(player, card_season_ids)
    @theme ||= insert_set(card_season_ids, { complete: card_season_ids.size }, key: "roguelike", params: { "theme" => "roguelike" })
    Game::AddGoal.new.call(player:, kind: "theme", key: "roguelike").value!
  end

  def sign_in(player)
    mock_steam_sign_in(player.steam_id)
    visit home_path(locale: :en)
    click_steam_sign_in
    assert_signed_in
  end

  def items_of(trade, side) = trade.items.select { it.side == side }.map(&:card_season_id)

  test "starting a trade from a suggestion opens the proposal with its cards placed, and the trade then runs as any other" do
    zoe = friend_of_hugo("Zoe", "76561197960287101")
    hold(@lea, @depths, 2)
    custom_goal(@hugo, "Crown run", [ @crown ])
    hold(zoe, @crown, 2)
    game_set_goal(zoe, [ @portal, @crown ])
    sign_in @hugo

    visit trades_path(locale: :en)
    assert_selector ".trade-suggestion", count: 2
    find(".trade-suggestion", text: "Golden Crown against Portal").find(".trade-suggestion__opener").click
    click_on "Send the proposal"

    assert_selector ".toast .toast__title", text: /PROPOSAL SENT/i
    trade = Game::Trade.sole
    assert_equal [ @crown ], items_of(trade, "request")
    assert_equal [ @portal ], items_of(trade, "offer")
    assert_equal 1, Game::Holding.find_by!(player_id: @hugo.id, card_season_id: @portal).reserved

    sign_out
    assert_signed_out
    sign_in zoe
    visit trade_path(locale: :en, token: trade.token)
    within(".trade-board") { click_on "Accept" }
    assert_selector ".trade-board .trade-chip--lime", text: /DONE/i
    assert_equal "accepted", trade.reload.status

    sign_out
    assert_signed_out
    sign_in @hugo
    visit trades_path(locale: :en)
    assert_selector ".trade-suggestion", count: 1
    assert_selector ".trade-suggestion__summary", text: "Blue Depths · for Lea to choose in return"
    assert_no_selector ".trade-suggestion__summary", text: "Golden Crown"
  end
end
