require "application_system_test_case"
require_relative "../support/custom_sets"
require_relative "../support/game_sets"
require_relative "../support/holdings"
require_relative "../support/steam_sign_in"

# Hugo aims at Tin Soldier, Green Hills and Blue Depths through a custom set,
# and holds the Soldier and two Portals. His friends hold the cards he misses;
# the tests play two and three of them through the Trades screen.
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
    custom_goal(@hugo, "Hugo's trio", [ @soldier, @hills, @depths ])
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

  def summaries = all(".trade-suggestion__summary").map(&:text)

  def items_of(trade, side) = trade.items.select { it.side == side }.map(&:card_season_id)

  test "a player with an active goal sees, in English and French, which friends hold a spare of each missing card" do
    zoe = friend_of_hugo("Zoe", "76561197960287101")
    hold(@lea, @depths)
    hold(@max, @hills)
    custom_goal(@hugo, "Crown run", [ @crown ])
    hold(zoe, @crown)
    sign_in @hugo

    visit trades_path(locale: :en)
    assert_selector ".trade-suggestions__heading", text: /SUGGESTIONS/i
    assert_selector ".trade-suggestion", count: 3
    assert_selector ".trade-suggestion__summary", text: "Blue Depths · for Lea to choose in return"
    assert_selector ".trade-suggestion__summary", text: "Green Hills · for Max to choose in return"
    assert_selector ".trade-suggestion__summary", text: "Golden Crown · for Zoe to choose in return"

    visit trades_path(locale: :fr)
    assert_selector ".trade-suggestions__heading", text: /SUGGESTIONS/i
    assert_selector ".trade-suggestion", count: 3
    assert_selector ".trade-suggestion__summary", text: "Profondeurs bleues · à Lea de choisir en retour"
    assert_selector ".trade-suggestion__summary", text: "Collines vertes · à Max de choisir en retour"
    assert_selector ".trade-suggestion__summary", text: "Couronne d'or · à Zoe de choisir en retour"
  end

  test "a suggestion where both sides need what the other spares is shown before the one-sided ones" do
    zoe = friend_of_hugo("Zoe", "76561197960287101")
    hold(@lea, @depths, 2)
    hold(@lea, @hills, 2)
    custom_goal(@hugo, "Crown run", [ @crown ])
    hold(zoe, @crown)
    game_set_goal(zoe, [ @portal, @crown ])
    sign_in @hugo

    visit trades_path(locale: :en)

    assert_selector ".trade-suggestion", count: 2
    eventually("the mutual suggestion first") do
      summaries == [ "Golden Crown against Portal", "Blue Depths, Green Hills · for Lea to choose in return" ]
    end
  end

  test "a friend's side reads only their game-set goals" do
    hold(@lea, @depths)
    hold(@max, @hills)
    game_set_goal(@lea, [ @portal, @crown ])
    custom_goal(@max, "Max wants Portal", [ @portal, @crown ])
    sign_in @hugo

    visit trades_path(locale: :en)

    assert_selector ".trade-suggestion", count: 2
    eventually("Lea mutual, Max one-sided") do
      summaries == [ "Blue Depths against Portal", "Green Hills · for Max to choose in return" ]
    end
  end

  test "a spared card is any free copy, and a double ranks first" do
    hold(@lea, @depths)
    hold(@lea, @hills, 2)
    sign_in @hugo

    visit trades_path(locale: :en)

    assert_selector ".trade-suggestion__summary", text: "Green Hills, Blue Depths · for Lea to choose in return"
  end

  test "starting a trade from a suggestion opens the proposal with its cards placed, and the trade then runs as any other" do
    zoe = friend_of_hugo("Zoe", "76561197960287101")
    hold(@lea, @depths)
    custom_goal(@hugo, "Crown run", [ @crown ])
    hold(zoe, @crown)
    game_set_goal(zoe, [ @portal, @crown ])
    sign_in @hugo

    visit trades_path(locale: :en)
    assert_selector ".trade-suggestion", count: 2
    find(".trade-suggestion", text: "Golden Crown against Portal").find(".trade-suggestion__send button", text: /SEND/i).click

    assert_selector ".toast .toast__title", text: /PROPOSAL FORWARDED/i
    trade = Game::Trade.sole
    assert_equal [ @crown ], items_of(trade, "request")
    assert_equal [ @portal ], items_of(trade, "offer")
    assert_equal 1, Game::Holding.find_by!(player_id: @hugo.id, card_season_id: @portal).reserved
    assert_selector ".trade-suggestion", count: 1

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

  test "the opener of a mutual suggestion places both sides of the proposal, which sends as it stands" do
    zoe = friend_of_hugo("Zoe", "76561197960287101")
    custom_goal(@hugo, "Crown run", [ @crown ])
    hold(zoe, @crown)
    game_set_goal(zoe, [ @portal, @crown ])
    sign_in @hugo

    visit trades_path(locale: :en)
    find(".trade-suggestion__opener").click

    assert_current_path new_trade_path(locale: :en, friend: zoe.token, take: %w[golden-crown--s1], give: %w[portal--s1])
    assert_selector ".trade-side--friend .trade-card__remove[aria-label='Remove Golden Crown']"
    assert_selector ".trade-side--own .trade-card__remove[aria-label='Remove Portal']"
    click_on "Send the proposal"

    assert_selector ".toast .toast__title", text: /PROPOSAL SENT/i
    trade = Game::Trade.sole
    assert_equal [ @crown ], items_of(trade, "request")
    assert_equal [ @portal ], items_of(trade, "offer")
  end

  test "a suggestion the friend declined never returns" do
    hold(@lea, @depths)
    hold(@lea, @hills)
    sign_in @hugo

    visit trades_path(locale: :en)
    find(".trade-suggestion__send button", text: /SEND/i).click
    assert_selector ".toast .toast__title", text: /PROPOSAL FORWARDED/i
    trade = Game::Trade.sole
    Game::DeclineTrade.new.call(player: @lea, trade_id: trade.id, revision: trade.revision).value!

    visit trades_path(locale: :en)
    assert_selector ".trade-row", text: /declined/
    assert_no_selector ".trade-suggestions"
  end

  test "two friends hold two open trades at once, each reserving only its own offer, and a repeated send creates no second trade" do
    extras = unheld_cards(4)
    custom_goal(@hugo, "Extras", extras)
    [ @depths, @hills, *extras ].each { hold(@lea, it) }
    game_set_goal(@lea, [ @portal, @soldier ])
    sign_in @hugo

    visit trades_path(locale: :en)
    assert_selector ".trade-suggestion", count: 1
    page.execute_script("window.staleSend = document.querySelector('.trade-suggestion__send form').outerHTML")
    find(".trade-suggestion__send button", text: /SEND/i).click

    assert_selector ".toast .toast__title", text: /PROPOSAL FORWARDED/i
    first_trade = Game::Trade.sole
    assert_equal 4, items_of(first_trade, "request").size
    assert_equal [ @portal, @soldier ].sort, items_of(first_trade, "offer").sort
    assert_selector ".trade-suggestion", count: 1, text: /for Lea to choose in return/

    find(".trade-suggestion__send button", text: /SEND/i).click
    eventually("the second trade is open") { Game::Trade.count == 2 }
    second_trade = Game::Trade.where.not(id: first_trade.id).sole
    assert_equal [ "open" ], Game::Trade.distinct.pluck(:status)
    assert_equal 2, items_of(second_trade, "request").size
    assert_empty items_of(second_trade, "offer")
    assert_equal [ @depths, @hills, *extras ].sort, (items_of(first_trade, "request") + items_of(second_trade, "request")).sort
    assert_equal [ 1, 1 ], [ @portal, @soldier ].map { Game::Holding.find_by!(player_id: @hugo.id, card_season_id: it).reserved }
    assert_equal 0, Game::Holding.where(player_id: @lea.id).sum(:reserved)

    page.execute_script("document.body.insertAdjacentHTML('beforeend', window.staleSend); document.body.lastElementChild.requestSubmit()")
    assert_selector ".toast", text: /Not enough copies/
    assert_equal 2, Game::Trade.count
  end

  test "no suggestion ever names a private player or reveals a collection its owner hides" do
    pia = friend_of_hugo("Pia", "76561197960287102")
    deleted = friend_of_hugo("Dee", "76561197960287103")
    banned = accounts_players(:banned)
    banned.update!(persona_name: "Bo")
    befriend(@hugo, banned)
    extras = unheld_cards(2)
    custom_goal(@hugo, "Crown run", [ @crown, *extras ])
    hold(@lea, @depths)
    hold(@max, @hills)
    hold(pia, @crown)
    hold(banned, extras.first)
    hold(deleted, extras.second)
    @max.update!(visibility: :friends_only)
    pia.update!(visibility: :private)
    Accounts::DeletePlayer.new.call(player: deleted).value!
    sign_in @hugo

    visit trades_path(locale: :en)

    assert_selector ".trade-suggestion", count: 2
    assert_selector ".trade-suggestion__summary", text: "Blue Depths · for Lea to choose in return"
    assert_selector ".trade-suggestion__summary", text: "Green Hills · for Max to choose in return"
    assert_no_selector ".trade-suggestion", text: /Golden Crown|Seed \d|for (Pia|Bo|Dee) to choose/

    pia.update!(visibility: :public)
    Accounts::UnbanPlayer.new.call(staff: @max, player: banned).value!
    visit trades_path(locale: :en)
    assert_selector ".trade-suggestion", count: 3
  end

  test "a private player sees no suggestion naming others" do
    hold(@lea, @depths)
    Accounts::SetVisibility.new.call(player: @hugo, visibility: "private").value!
    sign_in @hugo

    visit trades_path(locale: :en)

    assert_selector ".trades__list"
    assert_no_selector ".trade-suggestions"
  end
end
