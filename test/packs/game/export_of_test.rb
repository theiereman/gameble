require "test_helper"
require_relative "../../support/game_packs"
require_relative "../../support/game_trades"

class Game::ExportOfTest < ActiveSupport::TestCase
  include GamePacks
  include GameTrades

  setup do
    @player = accounts_players(:player)
    @friend = accounts_players(:moderator)
    @stranger = accounts_players(:administrator)
    @portal = catalog_card_seasons(:portal_one).id
    @common = catalog_card_seasons(:common_card_one).id
    @rare = catalog_card_seasons(:rare_card_one).id
    @legendary = catalog_card_seasons(:legendary_card_one).id
  end

  test "a new player's export holds their friend code and nothing else" do
    export = Game::ExportOf.call(@player)

    assert_equal "7K2Q-F3NX", export.friend_code
    %i[held_cards packs daily_bonus_days goal_reward_weeks contributions completed_sets discoveries feed_entries unlocks trades].each do
      assert_empty export.public_send(it), it
    end
    assert_equal 0, export.friend_count
    assert_equal [ 0, 0 ], [ export.invitations.received, export.invitations.sent ]
    assert_empty export.card_season_ids
  end

  test "opened packs give their cards, card back and the collection; a pack not opened yet hides its cards and back" do
    Game::FirstDiscovery.where(card_season_id: @legendary).delete_all
    opened = create_pack(@player, cards: [ @portal, @portal, @common, @rare, @legendary ], available_at: 2.minutes.ago)
    waiting = create_pack(@player, cards: Array.new(5, @rare), available_at: 1.hour.from_now)
    Game::OpenPack.new.call(player: @player).value!

    export = Game::ExportOf.call(@player)

    first, second = export.packs
    assert_equal [ opened.token, "regular", 1, "standard", [ @portal, @portal, @common, @rare, @legendary ] ],
      [ first.token, first.kind, first.season_number, first.card_back, first.card_season_ids ]
    assert_not_nil first.opened_at
    assert_equal [ waiting.token, nil, nil, [] ], [ second.token, second.opened_at, second.card_back, second.card_season_ids ]
    assert_equal [ [ @portal, 2 ], [ @common, 1 ], [ @rare, 1 ], [ @legendary, 1 ] ].sort,
      export.held_cards.map { [ it.card_season_id, it.quantity ] }.sort
    assert export.held_cards.all?(&:last_gained_at)
    assert_equal [ @legendary ], export.discoveries.map(&:card_season_id)
    assert_equal [ 1 ], export.contributions.map(&:openings)
    assert_includes export.feed_entries.map(&:kind), "discovery"
    assert_not_includes export.card_season_ids, nil
  end

  test "bonuses, rewards, completed sets and achievements are listed by date" do
    Game::CollectDailyBonus.new.call(player: @player).value!
    reward_pack = create_pack(@stranger, kind: :reward)
    Game::GoalReward.create!(player_id: @player.id, week_start: Date.new(2026, 10, 5), pack_id: reward_pack.id)
    Game::SetCompletion.create!(player_id: @player.id, set_id: catalog_sets(:valve_one).id, completed_at: Time.utc(2026, 10, 6))
    Game::AchievementUnlock.record(@player.id, :first_booster, Time.utc(2026, 10, 7))

    export = Game::ExportOf.call(@player)

    assert_equal [ Time.current.utc.to_date ], export.daily_bonus_days
    assert_equal [ Date.new(2026, 10, 5) ], export.goal_reward_weeks
    set = export.completed_sets.sole
    assert_equal [ 1, "publisher", "valve", Time.utc(2026, 10, 6) ], [ set.season_number, set.kind, set.key, set.completed_at ]
    assert_equal [ [ "first_booster", Time.utc(2026, 10, 7) ] ], export.unlocks.map { [ it.achievement, it.unlocked_at ] }
  end

  test "friends and pending invitations are counts" do
    Game::Friendship.create!(low_player_id: [ @player.id, @friend.id ].min, high_player_id: [ @player.id, @friend.id ].max)
    Game::Invitation.create!(sender_id: @stranger.id, recipient_id: @player.id)
    Game::Invitation.create!(sender_id: @player.id, recipient_id: Accounts::Player.create!(steam_id: "76561197960287099").id)
    Game::Invitation.create!(sender_id: @player.id, recipient_id: accounts_players(:banned).id)

    export = Game::ExportOf.call(@player)

    assert_equal 1, export.friend_count
    assert_equal 1, export.invitations.received
    assert_equal 1, export.invitations.sent
  end

  test "a trade gives its status, dates and only the cards the player gave, whichever side proposed" do
    conclude_trade(@friend, @player, offer: { @rare => 1 }, request: { @common => 2 })
    hold(@player, @portal, 1)
    hold(@stranger, @legendary, 1)
    befriend(@player, @stranger)
    Game::ProposeTrade.new.call(player: @player, recipient: @stranger, offer: { @portal => 1 }, request: { @legendary => 1 }).value!

    accepted, open = Game::ExportOf.call(@player).trades

    assert_equal [ "accepted", [ [ @common, 2 ] ] ], [ accepted.status, accepted.offered.map { [ it.card_season_id, it.quantity ] } ]
    assert_not_nil accepted.closed_at
    assert_equal [ "open", nil, [ [ @portal, 1 ] ] ], [ open.status, open.closed_at, open.offered.map { [ it.card_season_id, it.quantity ] } ]
    assert_equal [ :status, :proposed_at, :closed_at, :offered ], open.to_h.keys
  end

  test "an open trade past its expiry reads as expired" do
    hold(@player, @portal, 1)
    hold(@friend, @rare, 1)
    befriend(@player, @friend)
    Game::ProposeTrade.new.call(player: @player, recipient: @friend, offer: { @portal => 1 }, request: { @rare => 1 }).value!

    assert_equal [ "expired" ], Game::ExportOf.call(@player, now: 8.days.from_now).trades.map(&:status)
  end

  test "a trade feed entry gives the player's own card, as proposer or as partner" do
    conclude_trade(@friend, @player, offer: { @rare => 1 }, request: { @common => 1 })

    assert_equal [ [ "trade", @common ] ], Game::ExportOf.call(@player).feed_entries.map { [ it.kind, it.card_season_id ] }
    assert_equal [ [ "trade", @rare ] ], Game::ExportOf.call(@friend).feed_entries.map { [ it.kind, it.card_season_id ] }
  end

  test "another player's data stays out" do
    create_pack(@friend, opened_at: 1.minute.ago)
    hold(@friend, @rare, 3)
    Game::AchievementUnlock.record(@friend.id, :first_booster, Time.current)

    export = Game::ExportOf.call(@player)

    assert_empty export.packs
    assert_empty export.held_cards
    assert_empty export.unlocks
  end

  private
    def hold(player, card_season_id, quantity)
      holding = Game::Holding.find_or_initialize_by(player_id: player.id, card_season_id:)
      holding.update!(quantity: holding.quantity.to_i + quantity)
    end

    def befriend(one, other)
      low, high = [ one.id, other.id ].minmax
      Game::Friendship.find_or_create_by!(low_player_id: low, high_player_id: high)
    end
end
