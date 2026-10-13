require "test_helper"
require_relative "../../support/lock_races"

class Game::TradeConcurrencyTest < ActiveSupport::TestCase
  include LockRaces

  self.use_transactional_tests = false

  setup do
    @alice = accounts_players(:player)
    @bob = accounts_players(:moderator)
    @carol = accounts_players(:administrator)
    @card = catalog_card_seasons(:portal_one).id
    @other = catalog_card_seasons(:rare_card_one).id
    @players = [ @alice, @bob, @carol ]
  end

  teardown do
    Game::FeedEntry.where.not(trade_id: nil).delete_all
    Game::WeeklyContribution.where(player_id: (@players + (@created || [])).map(&:id)).delete_all
    Game::TradeItem.delete_all
    Game::Trade.delete_all
    Game::Holding.where(player_id: @players.map(&:id)).delete_all
    Game::SetCompletion.where(player_id: @players.map(&:id)).delete_all
    Game::Friendship.delete_all
    Game::Invitation.delete_all
    Accounts::Player.where(id: @created.map(&:id)).delete_all if @created
    Accounts::Player.where(id: @players.map(&:id)).update_all(visibility: "public")
    delete_events
  end

  def delete_events
    streams = @players.flat_map { |player| [ Game::Operation.stream_name(player.id), "Accounts::Player$#{player.id}" ] }
    connection = ActiveRecord::Base.connection
    event_ids = connection.select_values(ActiveRecord::Base.sanitize_sql_array([ "SELECT event_id FROM event_store_events_in_streams WHERE stream IN (?)", streams ]))
    connection.exec_delete(ActiveRecord::Base.sanitize_sql_array([ "DELETE FROM event_store_events_in_streams WHERE stream IN (?)", streams ]))
    connection.exec_delete(ActiveRecord::Base.sanitize_sql_array([ "DELETE FROM event_store_events WHERE event_id IN (?)", event_ids ])) if event_ids.any?
  end

  def befriend(first, second)
    low, high = [ first.id, second.id ].minmax
    Game::Friendship.create!(low_player_id: low, high_player_id: high)
  end

  def hold(player, card_season_id, quantity)
    Game::Holding.create!(player_id: player.id, card_season_id:, quantity:)
  end

  def reserved(player, card_season_id) = Game::Holding.uncached { Game::Holding.find_by(player_id: player.id, card_season_id:)&.reserved.to_i }

  def quantity(player, card_season_id) = Game::Holding.uncached { Game::Holding.find_by(player_id: player.id, card_season_id:)&.quantity.to_i }


  def propose(from, to, offer, request)
    -> { Game::ProposeTrade.new.call(player: Accounts::Player.find(from.id), recipient: Accounts::Player.find(to.id), offer:, request:) }
  end

  def accept(player, trade)
    revision = Game::Trade.find(trade.id).revision
    -> { Game::AcceptTrade.new.call(player: Accounts::Player.find(player.id), trade_id: trade.id, revision:) }
  end

  test "two proposals of the same copies to two friends at once: one reserves them, the other is refused" do
    befriend(@alice, @bob)
    befriend(@alice, @carol)
    hold(@alice, @card, 2)
    hold(@bob, @other, 1)
    hold(@carol, @other, 1)

    results = together(propose(@alice, @bob, { @card => 2 }, { @other => 1 }), propose(@alice, @carol, { @card => 2 }, { @other => 1 }))

    assert_equal 1, results.count(&:success?)
    assert_equal [ :insufficient_copies ], results.select(&:failure?).map(&:failure)
    assert_equal 2, reserved(@alice, @card)
    assert_equal 1, Game::Trade.count
  end

  test "a deletion racing proposals to the deleted player: no trade stays open, nothing stays reserved, no deadlock" do
    dave = Accounts::Player.create!(steam_id: "76561197960288101", persona_name: "Dave")
    @players += [ dave ]
    @created = [ dave ]
    befriend(@alice, dave)
    befriend(@carol, dave)
    hold(@alice, @card, 2)
    hold(@carol, @other, 1)
    hold(dave, @other, 1)
    hold(dave, @card, 1)

    results = together(-> { Accounts::DeletePlayer.new.call(player: Accounts::Player.find(dave.id)) },
      propose(@alice, dave, { @card => 2 }, { @other => 1 }), propose(@carol, dave, { @other => 1 }, { @card => 1 }))

    assert results.first.success?
    results.drop(1).select(&:failure?).each { |result| assert_equal :not_friends, result.failure }
    assert_equal 0, Game::Trade.in_progress.where(recipient_id: dave.id).count
    assert_equal 0, reserved(@alice, @card)
    assert_equal 0, reserved(@carol, @other)
    assert_equal 0, Game::Friendship.of(dave.id).count
  end

  def go_private(player)
    -> { Accounts::SetVisibility.new.call(player: Accounts::Player.find(player.id), visibility: "private") }
  end

  test "a proposal committed before its recipient goes private is cancelled by it, nothing left reserved" do
    befriend(@alice, @bob)
    hold(@bob, @other, 1)
    hold(@alice, @card, 1)

    proposal, change = first_holding_the_lock(propose(@bob, @alice, { @other => 1 }, { @card => 1 }), go_private(@alice))

    assert proposal.success?
    assert change.success?
    assert_equal "cancelled", Game::Trade.uncached { Game::Trade.sole.status }
    assert_equal 0, reserved(@bob, @other)
  end

  test "a proposal waiting behind its recipient going private is refused, nothing reserved" do
    befriend(@alice, @bob)
    hold(@bob, @other, 1)
    hold(@alice, @card, 1)

    change, proposal = first_holding_the_lock(go_private(@alice), propose(@bob, @alice, { @other => 1 }, { @card => 1 }))

    assert change.success?
    assert_equal Dry::Monads::Failure(:friend_profile_private), proposal
    assert_not Game::Trade.exists?
    assert_equal 0, reserved(@bob, @other)
  end

  test "going private racing proposals both ways: no trade stays open, nothing stays reserved, no deadlock" do
    befriend(@alice, @bob)
    befriend(@alice, @carol)
    hold(@alice, @card, 2)
    hold(@bob, @other, 1)
    hold(@carol, @other, 1)

    results = together(go_private(@alice),
      propose(@alice, @bob, { @card => 1 }, { @other => 1 }), propose(@carol, @alice, { @other => 1 }, { @card => 1 }))

    assert results.first.success?
    results.drop(1).select(&:failure?).each { |result| assert_includes %i[own_profile_private friend_profile_private], result.failure }
    assert_equal 0, Game::Trade.in_progress.count
    assert_equal 0, reserved(@alice, @card)
    assert_equal 0, reserved(@carol, @other)
  end

  test "many proposals of single copies at once never reserve more than owned" do
    friends = Array.new(5) { |index| Accounts::Player.create!(steam_id: "7656119796028800#{index}", persona_name: "Friend #{index}") }
    @players += friends
    @created = friends
    friends.each { |friend| befriend(@alice, friend) }
    hold(@alice, @card, 3)
    friends.each { |friend| hold(friend, @other, 1) }

    results = together(*friends.map { |friend| propose(@alice, friend, { @card => 1 }, { @other => 1 }) })

    assert_equal 3, results.count(&:success?)
    assert_equal [ :insufficient_copies ] * 2, results.select(&:failure?).map(&:failure)
    assert_equal 3, reserved(@alice, @card)
    assert_equal 3, Game::Trade.in_progress.count
  end

  test "opposite proposals of a pair at once: one opens the trade, the other is refused, no deadlock" do
    befriend(@alice, @bob)
    hold(@alice, @card, 1)
    hold(@bob, @other, 1)

    results = together(propose(@alice, @bob, { @card => 1 }, { @other => 1 }), propose(@bob, @alice, { @other => 1 }, { @card => 1 }))

    assert_equal 1, results.count(&:success?)
    assert_equal [ :trade_already_open ], results.select(&:failure?).map(&:failure)
    assert_equal 1, Game::Trade.count
  end

  test "crossing trades around three players, repeated, never deadlock and each reserves its own offer" do
    befriend(@alice, @bob)
    befriend(@bob, @carol)
    befriend(@alice, @carol)
    [ @alice, @bob, @carol ].each do |player|
      hold(player, @card, 1)
      hold(player, @other, 1)
    end
    pairs = [ [ @alice, @bob ], [ @bob, @carol ], [ @carol, @alice ] ]

    8.times do
      results = together(*pairs.map { |from, to| propose(from, to, { @other => 1, @card => 1 }, { @card => 1 }) })

      assert results.all?(&:success?), results.inspect
      assert_equal [ 1, 1, 1 ], @players.map { |player| reserved(player, @card) }
      cancels = together(*Game::Trade.uncached { Game::Trade.in_progress.to_a }.map { |trade| -> { Game::CancelTrade.new.call(player: Accounts::Player.find(trade.proposer_id), trade_id: trade.id) } })
      assert cancels.all?(&:success?), cancels.inspect
      assert_equal [ 0, 0, 0 ], @players.map { |player| reserved(player, @card) }
    end
  end

  test "a cancel and a decline racing on one trade: exactly one closes it and releases once" do
    befriend(@alice, @bob)
    hold(@alice, @card, 2)
    hold(@bob, @other, 1)
    trade = propose(@alice, @bob, { @card => 2 }, { @other => 1 }).call.value!
    revision = Game::Trade.find(trade.id).revision

    results = together(
      -> { Game::CancelTrade.new.call(player: Accounts::Player.find(@alice.id), trade_id: trade.id) },
      -> { Game::DeclineTrade.new.call(player: Accounts::Player.find(@bob.id), trade_id: trade.id, revision:) }
    )

    assert_equal 1, results.count(&:success?)
    assert_equal [ :trade_not_open ], results.select(&:failure?).map(&:failure)
    assert_equal 0, reserved(@alice, @card)
    assert_not trade.reload.open?
  end

  test "a proposal racing a cancel of the previous trade never reserves beyond owned" do
    befriend(@alice, @bob)
    befriend(@alice, @carol)
    hold(@alice, @card, 2)
    hold(@bob, @other, 1)
    hold(@carol, @other, 1)
    trade = propose(@alice, @bob, { @card => 2 }, { @other => 1 }).call.value!

    together(
      -> { Game::CancelTrade.new.call(player: Accounts::Player.find(@alice.id), trade_id: trade.id) },
      propose(@alice, @carol, { @card => 2 }, { @other => 1 })
    )

    assert_includes [ 0, 2 ], reserved(@alice, @card)
    assert_equal reserved(@alice, @card), Game::Trade.in_progress.where(proposer_id: @alice.id).count * 2
  end

  test "two acceptances at once of trades asking for the same last copy: one swaps, the other moves nothing" do
    befriend(@alice, @bob)
    befriend(@carol, @bob)
    hold(@alice, @card, 1)
    hold(@carol, @card, 1)
    hold(@bob, @other, 1)
    first = propose(@alice, @bob, { @card => 1 }, { @other => 1 }).call.value!
    second = propose(@carol, @bob, { @card => 1 }, { @other => 1 }).call.value!

    results = together(accept(@bob, first), accept(@bob, second))

    assert_equal 1, results.count(&:success?)
    assert_equal [ :requested_cards_unavailable ], results.select(&:failure?).map(&:failure)
    assert_equal [ 0, 0 ], [ quantity(@bob, @other), reserved(@bob, @other) ]
    assert_equal 1, quantity(@bob, @card)
    assert_equal 1, quantity(@alice, @other) + quantity(@carol, @other), "the last copy went to one proposer only"
    assert_equal 1, Game::Trade.where(status: "accepted").count
    assert_equal 1, Game::Trade.in_progress.count
  end

  test "the same trade accepted twice at once swaps once" do
    befriend(@alice, @bob)
    hold(@alice, @card, 2)
    hold(@bob, @other, 3)
    trade = propose(@alice, @bob, { @card => 2 }, { @other => 1 }).call.value!

    results = together(accept(@bob, trade), accept(@bob, trade))

    assert_equal 1, results.count(&:success?)
    assert_equal [ :trade_not_open ], results.select(&:failure?).map(&:failure)
    assert_equal [ 0, 1, 2, 2 ], [ quantity(@alice, @card), quantity(@alice, @other), quantity(@bob, @card), quantity(@bob, @other) ]
    assert_equal 0, reserved(@alice, @card)
  end

  test "an acceptance racing a counter and a cancel of the same trade: exactly one acts" do
    befriend(@alice, @bob)
    hold(@alice, @card, 5)
    hold(@bob, @other, 5)

    4.times do
      trade = propose(@alice, @bob, { @card => 1 }, { @other => 1 }).call.value!
      revision = Game::Trade.find(trade.id).revision
      results = together(
        accept(@bob, trade),
        -> { Game::CounterTrade.new.call(player: Accounts::Player.find(@bob.id), trade_id: trade.id, revision:, offer: { @other => 1 }, request: { @card => 1 }) },
        -> { Game::CancelTrade.new.call(player: Accounts::Player.find(@alice.id), trade_id: trade.id) }
      )

      assert_equal 1, results.count(&:success?), results.inspect
      trade.reload
      Game::CancelTrade.new.call(player: Accounts::Player.find(trade.proposer_id), trade_id: trade.id).value! if trade.open?
      [ @alice, @bob ].each do |player|
        assert_equal [ 0, 0 ], [ reserved(player, @card), reserved(player, @other) ], results.inspect
      end
      assert_equal 5, quantity(@alice, @card) + quantity(@bob, @card)
      assert_equal 5, quantity(@alice, @other) + quantity(@bob, @other)
    end
  end

  test "crossing acceptances around three players at once never deadlock" do
    befriend(@alice, @bob)
    befriend(@bob, @carol)
    befriend(@alice, @carol)
    [ @alice, @bob, @carol ].each do |player|
      hold(player, @card, 1)
      hold(player, @other, 1)
    end
    trades = [ [ @alice, @bob ], [ @bob, @carol ], [ @carol, @alice ] ].map { |from, to| propose(from, to, { @card => 1 }, { @other => 1 }).call.value! }

    results = together(*trades.map { |trade| accept(Accounts::Player.find(trade.recipient_id), trade) })

    assert results.all?(&:success?), results.inspect
    assert_equal [ 1, 1, 1 ], @players.map { |player| quantity(player, @card) }
    assert_equal [ 1, 1, 1 ], @players.map { |player| quantity(player, @other) }
    assert_equal [ 0, 0, 0 ], @players.map { |player| reserved(player, @card) }
  end

  def accepted_invitations
    @players.sum { |player| Rails.configuration.event_store.read.stream(Game::Operation.stream_name(player.id)).of_type([ Game::InvitationAccepted ]).count }
  end

  test "two players inviting each other at once become friends once, with no invitation left open" do
    3.times do
      results = together(
        -> { Game::SendInvitation.new.call(player: Accounts::Player.find(@alice.id), recipient_token: @bob.token) },
        -> { Game::SendInvitation.new.call(player: Accounts::Player.find(@bob.id), recipient_token: @alice.token) }
      )

      assert results.all?(&:success?), results.inspect
      assert_equal 1, Game::Friendship.count
      assert_equal 1, accepted_invitations
      assert_equal [ "accepted" ], Game::Invitation.distinct.pluck(:status)
      Game::Friendship.delete_all
      Game::Invitation.delete_all
      delete_events
    end
  end

  test "crossing invitations accepted at once make one friendship, announced once" do
    3.times do
      alices = Game::Invitation.create!(sender_id: @alice.id, recipient_id: @bob.id)
      bobs = Game::Invitation.create!(sender_id: @bob.id, recipient_id: @alice.id)

      results = together(
        -> { Game::AcceptInvitation.new.call(player: Accounts::Player.find(@bob.id), token: alices.token) },
        -> { Game::AcceptInvitation.new.call(player: Accounts::Player.find(@alice.id), token: bobs.token) }
      )

      assert_equal 1, results.count(&:success?), results.inspect
      assert_equal [ :not_found ], results.select(&:failure?).map(&:failure)
      assert_equal 1, Game::Friendship.count
      assert_equal 1, accepted_invitations
      assert_equal [ "accepted" ], Game::Invitation.distinct.pluck(:status)
      Game::Friendship.delete_all
      Game::Invitation.delete_all
      delete_events
    end
  end
end
