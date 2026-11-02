require "test_helper"
require_relative "../../support/custom_sets"
require_relative "../../support/game_sets"
require_relative "../../support/holdings"

# Which friends hold, as a duplicate, the games the player's goals miss: at
# most three suggestions, one per friend and at most one per goal, up to four
# of the friend's cards each.
class Game::TradeSuggestionsTest < ActiveSupport::TestCase
  include CustomSets
  include GameSets
  include Holdings

  setup do
    @player = accounts_players(:player)
    @lea = accounts_players(:moderator)
    @max = accounts_players(:administrator)
    @portal = catalog_card_seasons(:portal_one)
    @soldier = catalog_card_seasons(:common_card_one)
    @hills = catalog_card_seasons(:uncommon_card_one)
    @depths = catalog_card_seasons(:rare_card_one)
    @crown = catalog_card_seasons(:legendary_card_one)
  end

  def befriend(friend, at: Time.current)
    low, high = [ @player.id, friend.id ].minmax
    Game::Friendship.create!(low_player_id: low, high_player_id: high, created_at: at)
  end

  def new_friend(number, at: Time.current)
    Accounts::Player.create!(steam_id: "7656119796099#{number.to_s.rjust(4, "0")}").tap { befriend(it, at:) }
  end

  def goal(*card_season_ids, name: "Mes favoris #{SecureRandom.hex(2)}")
    card_ids = padded_to_three(Catalog::CardSeason.where(id: card_season_ids).pluck(:card_id))
    Game::AddGoal.new.call(player: @player, custom_set: create_custom_set(@player, name:, card_ids:).token).value!
  end

  def padded_to_three(card_ids)
    return card_ids if card_ids.size >= 3

    card_ids + Catalog::CardSeason.where(id: unheld_cards(3 - card_ids.size)).pluck(:card_id)
  end

  def spare(friend, *card_season_ids, copies: 2)
    card_season_ids.each { hold(friend, it, copies) }
  end

  def second_edition(card_season, rarity:)
    season = Catalog::Season.find_by(number: 2) || Catalog::Season.create!(status: :published, number: 2, published_at: Time.current)
    Catalog::CardSeason.insert_all!([ { card_id: card_season.card_id, season_id: season.id, prestige_score: 0.5, rating: 80.0,
      rarity: Catalog::Rarity::TIERS.invert.fetch(rarity), number: Catalog::CardSeason.where(season_id: season.id).count + 1 } ],
      returning: :id).rows.flatten.sole
  end

  def suggestions = Game::TradeSuggestions.call(@player).suggestions

  def placed = suggestions.map { [ it.player, it.card_season_ids ] }

  def count_queries(&block)
    queries = 0
    counter = ->(*, payload) { queries += 1 unless payload[:name].in?([ "SCHEMA", "TRANSACTION" ]) || payload[:cached] }
    ActiveSupport::Notifications.subscribed(counter, "sql.active_record", &block)
    queries
  end

  test "a friend holding a spare of each missing game is suggested with both, the player's side empty" do
    befriend(@lea)
    hold(@player, @hills.id)
    goal(@portal.id, @depths.id, @hills.id)
    spare(@lea, @portal.id, @depths.id)

    result = Game::TradeSuggestions.call(@player)

    suggestion = result.suggestions.sole
    assert_equal @lea, suggestion.player
    assert_equal [ @depths.id, @portal.id ].sort, suggestion.card_season_ids.sort
    assert_equal [ [ 1 ], [ 1 ] ], suggestion.lines.map(&:goal_positions)
    assert_equal [ 1, 1 ], suggestion.lines.map(&:quantity)
    assert_empty suggestion.own_lines
    assert_equal({ 1 => 2 }, suggestion.served_goals)
    assert_equal [ 1 ], result.goals.map(&:position)
    assert_equal [ @depths.id, @portal.id ].sort, result.card_season_ids.sort
  end

  test "a single free copy, whether the only one or the one left by a reservation, is never suggested" do
    befriend(@lea)
    befriend(@max)
    hugo = new_friend(1)
    goal(@portal.id, @depths.id, @hills.id)
    hold(@lea, @portal.id, 1)
    hold(@max, @portal.id, 2, reserved: 1)

    assert_empty suggestions

    hold(hugo, @portal.id, 3, reserved: 1)

    assert_equal [ [ hugo, [ @portal.id ] ] ], placed
  end

  test "only the cards with at least two free copies are placed" do
    befriend(@lea)
    goal(@portal.id, @depths.id, @hills.id)
    hold(@lea, @portal.id, 3, reserved: 1)
    hold(@lea, @hills.id, 2, reserved: 1)
    hold(@lea, @depths.id, 3)

    assert_equal [ [ @lea, [ @depths.id, @portal.id ].sort ] ], placed.map { |friend, ids| [ friend, ids.sort ] }
  end

  test "editions are summed: two editions with a free copy each make a duplicate and the earliest season is placed" do
    befriend(@lea)
    goal(@portal.id, @depths.id, @hills.id)
    common_portal = second_edition(@portal, rarity: :common)
    hold(@lea, @portal.id, 1)
    hold(@lea, common_portal, 1)

    assert_equal [ [ @lea, [ @portal.id ] ] ], placed
  end

  test "among the free copies, the edition with the most is placed, then the earliest season" do
    befriend(@lea)
    goal(@portal.id, @depths.id, @hills.id)
    common_portal = second_edition(@portal, rarity: :common)
    hold(@lea, @portal.id, 2)
    hold(@lea, common_portal, 2)

    assert_equal [ [ @lea, [ @portal.id ] ] ], placed

    Game::Holding.where(player_id: @lea.id, card_season_id: common_portal).update_all(quantity: 3)

    assert_equal [ [ @lea, [ common_portal ] ] ], placed
  end

  test "a game on the friend's side of an open trade between the two is no spare, whoever proposed it, until it expires" do
    befriend(@lea)
    befriend(@max)
    goal(@portal.id)
    goal(@depths.id)
    spare(@lea, @portal.id)
    spare(@max, @depths.id, copies: 3)
    requested = Game::ProposeTrade.new.call(player: @player, recipient: @lea, offer: {}, request: { @portal.id => 1 }).value!
    hold(@player, @soldier.id)
    offered = Game::ProposeTrade.new.call(player: @max, recipient: @player, offer: { @depths.id => 1 }, request: { @soldier.id => 1 }).value!

    assert_empty suggestions

    Game::Trade.where(id: [ requested.id, offered.id ]).update_all(expires_at: 1.minute.ago)

    assert_equal [ [ @lea, [ @portal.id ] ], [ @max, [ @depths.id ] ] ].sort_by { it.first.id }, placed.sort_by { it.first.id }
  end

  test "a private, banned or deleted friend is never suggested" do
    banned = accounts_players(:banned)
    deleted = new_friend(1)
    [ @lea, banned ].each { befriend(it) }
    goal(@portal.id, @depths.id, @hills.id)
    [ @lea, banned, deleted ].each { spare(it, @portal.id) }
    @lea.update_columns(visibility: "private")
    Accounts::DeletePlayer.new.call(player: deleted).value!

    assert_empty suggestions
  end

  test "a private player, a player with no goal or with nothing missing has no suggestion" do
    befriend(@lea)
    spare(@lea, @portal.id, @depths.id, @hills.id)

    assert_empty suggestions

    goal(@portal.id, @depths.id, @hills.id)
    @player.update_columns(visibility: "private")

    assert_empty Game::TradeSuggestions.call(@player.reload).then { [ *it.suggestions, *it.goals ] }

    @player.update_columns(visibility: "public")
    [ @portal, @depths, @hills ].each { hold(@player, it.id) }

    assert_empty suggestions
  end

  test "a Steam library set never feeds suggestions" do
    befriend(@lea)
    insert_set([ @soldier.id, @crown.id ], { complete: 2 }, key: "roguelike", params: { "theme" => "roguelike" })
    Game::AddGoal.new.call(player: @player, kind: "theme", key: "roguelike").value!
    create_library_set(@player, card_ids: [ @portal.card_id, @depths.card_id, @hills.card_id ])
    spare(@lea, @portal.id, @depths.id, @hills.id)

    result = Game::TradeSuggestions.call(@player)

    assert_equal [ 1 ], result.goals.map(&:position)
    assert_empty result.suggestions
  end

  test "more than four spares: the lowest goal's games first, then the rarest, then by slug" do
    befriend(@lea)
    unheld = unheld_cards(1).sole
    goal(@soldier.id, unheld, @depths.id)
    goal(@portal.id, @crown.id, @hills.id)
    spare(@lea, @soldier.id, unheld, @depths.id, @portal.id, @crown.id, @hills.id)

    suggestion = suggestions.sole

    assert_equal [ @depths.id, @soldier.id, unheld, @crown.id ], suggestion.card_season_ids
    assert_equal({ 1 => 3, 2 => 1 }, suggestion.served_goals)
  end

  test "a goal gets one suggestion, from the friend who spares the most; a game spared by two friends is placed on the higher one only" do
    hugo = new_friend(1)
    [ @lea, @max ].each { befriend(it) }
    goal(@portal.id, @depths.id, @hills.id, @crown.id)
    spare(@lea, @portal.id, @depths.id, @hills.id)
    spare(@max, @portal.id, @crown.id)
    spare(hugo, @portal.id)

    assert_equal [ [ @lea, [ @portal.id, @depths.id, @hills.id ].sort ] ], placed.map { |friend, ids| [ friend, ids.sort ] }
  end

  test "a goal with many missing games still gives one suggestion, and never more than three in all" do
    wanted = unheld_cards(50)
    goal(*wanted)
    4.times { |index| spare(new_friend(index + 1), *wanted.slice(index * 12, 12)) }

    assert_equal 1, suggestions.size

    4.times do |index|
      other = unheld_cards(2)
      goal(*other)
      spare(new_friend(index + 10), other.first)
    end

    assert_equal 3, suggestions.size
  end

  test "a game of a goal that already has a suggestion is left out, even when it also serves another goal" do
    befriend(@lea)
    befriend(@max)
    goal(@portal.id)
    goal(@portal.id, @depths.id)
    spare(@lea, @portal.id)
    spare(@max, @depths.id)

    assert_equal [ [ @lea, [ @portal.id ] ] ], placed
  end

  test "friends rank by their spare games, then the oldest friendship; three at most" do
    first, second, third = [ 3.days.ago, 1.day.ago, 2.days.ago ].each_with_index.map { |at, index| new_friend(index + 1, at:) }
    befriend(@lea)
    extra = unheld_cards(2)
    goal(@soldier.id, @hills.id, @depths.id)
    goal(@portal.id, @crown.id)
    goal(extra.first)
    goal(extra.last)
    spare(@lea, @soldier.id, @hills.id, @depths.id)
    spare(first, extra.first)
    spare(second, extra.last)
    spare(third, @portal.id, @crown.id)

    assert_equal [ @lea, third, first ], suggestions.map(&:player)
  end

  test "friends level on spares and friendship age rank by token" do
    at = 1.day.ago
    friends = [ new_friend(1, at:), new_friend(2, at:) ]
    goal(@portal.id)
    goal(@depths.id)
    spare(friends.first, @portal.id)
    spare(friends.last, @depths.id)

    assert_equal friends.sort_by(&:token), suggestions.map(&:player)
  end

  test "the reads cost the same with one friend or three" do
    goal(@portal.id)
    goal(@depths.id)
    goal(@hills.id)
    befriend(@lea)
    spare(@lea, @portal.id)
    one = count_queries { assert_equal 1, suggestions.size }

    befriend(@max)
    spare(@max, @depths.id)
    spare(new_friend(1), @hills.id)

    assert_equal one, count_queries { assert_equal 3, suggestions.size }
  end

  def game_set_goal(friend, *card_season_ids, key: "mutual-#{SecureRandom.hex(3)}")
    insert_set(card_season_ids, { complete: card_season_ids.size }, key:, params: { "theme" => key })
    Game::AddGoal.new.call(player: friend, kind: "theme", key:).value!
  end

  test "a mutual suggestion comes before a one-sided friend who spares more, with the player's spares on the give side" do
    befriend(@lea)
    befriend(@max)
    goal(@portal.id)
    goal(@depths.id, @hills.id)
    spare(@player, @soldier.id)
    spare(@lea, @portal.id)
    spare(@max, @portal.id, @depths.id)
    game_set_goal(@lea, @soldier.id, *unheld_cards(2))

    result = Game::TradeSuggestions.call(@player).suggestions

    assert_equal [ @lea, @max ], result.map(&:player)
    assert_predicate result.first, :mutual?
    assert_equal [ @soldier.id ], result.first.own_card_season_ids
    assert_equal [ @portal.id ], result.first.card_season_ids
    assert_equal [ @depths.id ], result.last.card_season_ids
    assert_empty result.last.own_lines
  end

  test "a friend's goal on a custom set never makes a suggestion mutual" do
    befriend(@lea)
    goal(@portal.id, @depths.id, @hills.id)
    spare(@player, @soldier.id)
    spare(@lea, @portal.id)
    card_ids = Catalog::CardSeason.where(id: [ @soldier.id, *unheld_cards(2) ]).pluck(:card_id)
    Game::AddGoal.new.call(player: @lea, custom_set: create_custom_set(@lea, name: "Private", card_ids:).token).value!

    suggestion = suggestions.sole

    assert_not_predicate suggestion, :mutual?
    assert_empty suggestion.own_lines
  end

  test "a game the friend already holds is not given" do
    befriend(@lea)
    goal(@portal.id, @depths.id, @hills.id)
    spare(@player, @soldier.id)
    spare(@lea, @portal.id)
    hold(@lea, @soldier.id)
    game_set_goal(@lea, @soldier.id, *unheld_cards(2))

    assert_not_predicate suggestions.sole, :mutual?
  end

  test "the give side holds up to four spares, ranked on the friend's goals" do
    befriend(@lea)
    goal(@portal.id, @depths.id, @hills.id)
    spare(@lea, @portal.id)
    cards = unheld_cards(5)
    cards.each { hold(@player, it, 2) }
    spare(@player, @crown.id)
    game_set_goal(@lea, *cards)
    game_set_goal(@lea, @crown.id)

    suggestion = suggestions.sole

    assert_equal 4, suggestion.own_lines.size
    assert_equal cards.first(4).sort, suggestion.own_card_season_ids.sort
    assert(suggestion.own_lines.all? { it.goal_positions.empty? })
  end

  test "a spare of the player is placed on one give side only, and each friend's cards once" do
    befriend(@lea)
    befriend(@max)
    goal(@portal.id, @depths.id)
    goal(@hills.id)
    goal(@crown.id)
    spare(@player, @soldier.id)
    spare(@lea, @portal.id, @depths.id, @hills.id)
    spare(@max, @portal.id, @depths.id, @crown.id)
    game_set_goal(@lea, @soldier.id, *unheld_cards(2))
    game_set_goal(@max, @soldier.id, *unheld_cards(2))

    result = suggestions

    assert_equal [ @lea, @max ], result.map(&:player)
    assert_equal [ [ @soldier.id ], [] ], result.map(&:own_card_season_ids)
    assert_equal [ [ @portal.id, @depths.id, @hills.id ].sort, [ @crown.id ] ], result.map { it.card_season_ids.sort }
  end

  test "the cards of a trade the friend declined are never suggested again to that friend, on either side, but still to the others" do
    befriend(@lea)
    befriend(@max)
    goal(@portal.id)
    goal(@depths.id, @hills.id)
    spare(@player, @soldier.id)
    spare(@lea, @portal.id, @depths.id)
    spare(@max, @portal.id)
    game_set_goal(@lea, @soldier.id, *unheld_cards(2))
    game_set_goal(@max, @soldier.id, *unheld_cards(2))
    trade = Game::ProposeTrade.new.call(player: @player, recipient: @lea, offer: { @soldier.id => 1 }, request: { @portal.id => 1 }).value!
    Game::DeclineTrade.new.call(player: @lea, trade_id: trade.id, revision: Game::Trade.find(trade.id).revision).value!

    by_friend = suggestions.index_by(&:player)

    assert_equal [ @depths.id ], by_friend.fetch(@lea).card_season_ids
    assert_empty by_friend.fetch(@lea).own_lines
    assert_equal [ @portal.id ], by_friend.fetch(@max).card_season_ids
    assert_equal [ @soldier.id ], by_friend.fetch(@max).own_card_season_ids
  end

  test "a friend whose give side an earlier friend emptied ranks after a mutual friend ranked below it" do
    first = new_friend(1, at: 3.days.ago)
    emptied = new_friend(2, at: 2.days.ago)
    mutual = new_friend(3, at: 1.day.ago)
    wanted = unheld_cards(4)
    goal(wanted[0], wanted[1])
    goal(wanted[2])
    goal(wanted[3])
    spare(@player, @soldier.id, @crown.id)
    spare(first, wanted[0], wanted[1])
    spare(emptied, wanted[2])
    spare(mutual, wanted[3])
    game_set_goal(first, @soldier.id, *unheld_cards(2))
    game_set_goal(emptied, @soldier.id, *unheld_cards(2))
    game_set_goal(mutual, @crown.id, *unheld_cards(2))

    result = suggestions

    assert_equal [ first, mutual, emptied ], result.map(&:player)
    assert_equal [ true, true, false ], result.map(&:mutual?)
  end

  test "the reads cost the same with one mutual friend or thirty" do
    goal(@portal.id)
    goal(@depths.id)
    goal(@hills.id)
    spare(@player, @soldier.id)
    befriend(@lea)
    spare(@lea, @portal.id)
    game_set_goal(@lea, @soldier.id, *unheld_cards(2))
    one = count_queries { assert_equal 1, suggestions.size }

    29.times do |index|
      friend = new_friend(index + 1)
      spare(friend, @depths.id)
      game_set_goal(friend, @soldier.id, *unheld_cards(1))
    end

    assert_equal one, count_queries { assert_operator suggestions.size, :>=, 2 }
  end

  test "the read still finds three mutual suggestions among 100 friends with five goals of fifty games" do
    wanted = unheld_cards(250)
    offered = unheld_cards(250)
    wanted.each_slice(50).with_index { |members, index| game_set_goal(@player, *members, key: "wanted-#{index}") }
    offered.each_slice(50).with_index { |members, index| insert_set(members, { complete: 50 }, key: "offered-#{index}", params: { "theme" => "offered-#{index}" }) }
    hold_all(@player, offered.each_slice(50).flat_map { it.first(10) }, quantity: 2)
    now = Time.current
    friends = Array.new(100) { |index| Accounts::Player.create!(steam_id: "7656119796098#{index.to_s.rjust(4, "0")}") }
    Game::Friendship.insert_all!(friends.map { |friend| low, high = [ @player.id, friend.id ].minmax; { low_player_id: low, high_player_id: high, created_at: now } })
    Game::Goal.insert_all!(friends.flat_map do |friend|
      5.times.map { |index| { player_id: friend.id, position: index + 1, set_kind: "theme", set_key: "offered-#{index}", created_at: now, updated_at: now } }
    end)
    friends.each { |friend| hold_all(friend, wanted.each_slice(50).flat_map { it.first(15) }, quantity: 2) }

    result = Game::TradeSuggestions.call(@player)

    assert_equal 3, result.suggestions.size
    assert(result.suggestions.all?(&:mutual?))
  end
end
