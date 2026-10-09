require "test_helper"
require_relative "../../support/rake_tasks"

class Game::DropFriendsAndTradesTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper
  include RakeTasks

  setup do
    @alice = accounts_players(:player)
    @bob = accounts_players(:moderator)
    @carol = accounts_players(:administrator)
    @portal = catalog_card_seasons(:portal_one).id
    @depths = catalog_card_seasons(:rare_card_one).id
    @soldier = catalog_card_seasons(:common_card_one).id
    [ [ @alice, @bob ], [ @alice, @carol ], [ @bob, @carol ] ].each { |pair| befriend(*pair) }
    hold(@alice, @portal, 3)
    hold(@bob, @depths, 2)
    hold(@carol, @soldier, 2)
    hold(@carol, @depths, 1)
    rake_task("game:drop_friends_and_trades")
  end

  def befriend(first, second)
    low, high = [ first.id, second.id ].minmax
    Game::Friendship.create!(low_player_id: low, high_player_id: high)
  end

  def hold(player, card_season_id, quantity) = Game::Holding.create!(player_id: player.id, card_season_id:, quantity:)
  def holding(player, card_season_id) = Game::Holding.find_by(player_id: player.id, card_season_id:)
  def propose(from, to, offer, request) = Game::ProposeTrade.new.call(player: from, recipient: to, offer:, request:).value!
  def friends?(first, second) = Game::FriendshipBetween.call(first, second)
  def invite(from, to, status: "pending") = Game::Invitation.create!(sender_id: from.id, recipient_id: to.id, status:)
  def ties_of(player) = Game::Friendship.of(player.id).count + Game::Invitation.where(sender_id: player.id).or(Game::Invitation.where(recipient_id: player.id)).count

  def ban(player)
    player.update!(banned_at: Time.current)
    Rails.configuration.event_store.publish(Accounts::PlayerBanned.new(data: { player_id: player.id }), stream_name: "Accounts::Player$#{player.id}")
  end

  test "deleting the recipient of a trade cancels it, releases the proposer's copies and ends the friendship" do
    trade = propose(@alice, @bob, { @portal => 2 }, { @depths => 1 })
    assert_equal 2, holding(@alice, @portal).reserved

    Accounts::DeletePlayer.new.call(player: @bob).value!

    trade.reload
    assert_equal "cancelled", trade.status
    assert_not_nil trade.closed_at
    assert_equal [ 3, 0 ], holding(@alice, @portal).slice(:quantity, :reserved).values
    assert_not friends?(@alice, @bob)
    assert_not_includes Game::FriendsOf.call(@alice), @bob
    assert friends?(@alice, @carol)
  end

  test "deleting the proposer of a trade cancels it; their cards go with the deletion" do
    trade = propose(@bob, @alice, { @depths => 1 }, { @portal => 1 })

    Accounts::DeletePlayer.new.call(player: @bob).value!

    assert_equal "cancelled", trade.reload.status
    assert_nil holding(@bob, @depths)
    assert_equal [ 3, 0 ], holding(@alice, @portal).slice(:quantity, :reserved).values
    assert_equal Dry::Monads::Failure(:trade_not_open), Game::AcceptTrade.new.call(player: @alice, trade_id: trade.id, revision: Game::Trade.find(trade.id).revision)
  end

  test "a ban cancels the player's trades on both sides, releases every reservation and keeps their cards" do
    theirs = propose(@carol, @alice, { @soldier => 2 }, { @portal => 1 })
    yours = propose(@alice, @bob, { @portal => 2 }, { @depths => 1 })
    between_others = propose(@bob, @carol, { @depths => 1 }, { @soldier => 1 })

    ban(@carol)

    assert_equal "cancelled", theirs.reload.status
    assert_equal [ 2, 0 ], holding(@carol, @soldier).slice(:quantity, :reserved).values
    assert_equal "cancelled", between_others.reload.status
    assert_equal 0, holding(@bob, @depths).reserved
    assert_predicate yours.reload, :open?
    assert_equal 2, holding(@alice, @portal).reserved
    assert_not friends?(@alice, @carol)
    assert_not friends?(@bob, @carol)
    assert friends?(@alice, @bob)
  end

  test "the player's invitations go in both directions, whatever their status; the others' stay" do
    stranger = Accounts::Player.create!(steam_id: "76561197960299001", persona_name: "Sam")
    sent = invite(@bob, stranger)
    received = invite(stranger, @bob)
    accepted = invite(@carol, @bob, status: "accepted")
    others = invite(@alice, stranger)

    Accounts::DeletePlayer.new.call(player: @bob).value!

    assert_empty Game::Invitation.where(id: [ sent.id, received.id, accepted.id ])
    assert Game::Invitation.exists?(others.id)
    assert_equal [ @alice ], Game::InvitationsOf.call(stranger).received.map(&:player)
    assert_empty Game::InvitationsOf.call(stranger).sent
    assert_equal Dry::Monads::Failure(:not_found), Game::AcceptInvitation.new.call(player: stranger, token: received.token)
  end

  test "a friendship or an invitation that outlived a deletion (a race) never shows the deleted player" do
    invitation = invite(@bob, @carol)
    @bob.update_columns(steam_id: nil, persona_name: nil, deleted_at: Time.current)

    assert_not_includes Game::FriendsOf.call(@alice), @bob
    assert_empty Game::InvitationsOf.call(@carol).received
    assert_equal Dry::Monads::Failure(:not_found), Game::AcceptInvitation.new.call(player: @carol, token: invitation.token)
  end

  test "nothing is published, and a second run finds nothing to do" do
    propose(@alice, @bob, { @portal => 2 }, { @depths => 1 })
    events = Rails.configuration.event_store.read.to_a.size

    assert Game::DropFriendsAndTrades.new.call(player: @bob).success?
    assert Game::DropFriendsAndTrades.new.call(player: @bob).success?

    assert_equal events, Rails.configuration.event_store.read.to_a.size
    assert_equal 0, holding(@alice, @portal).reserved
    assert_equal 0, ties_of(@bob)
  end

  test "only a saved player is accepted" do
    assert_equal Dry::Monads::Failure(:player_required), Game::DropFriendsAndTrades.new.call(player: nil)
    assert_equal Dry::Monads::Failure(:player_required), Game::DropFriendsAndTrades.new.call(player: Accounts::Player.new)
  end

  test "the sweep cuts off players banned from the console and deleted before, and leaves the others" do
    banned = accounts_players(:banned)
    befriend(banned, @alice)
    invite(banned, @carol)
    hold(banned, @soldier, 1)
    trade = propose(@alice, @bob, { @portal => 1 }, { @depths => 1 })
    @bob.update_columns(steam_id: nil, persona_name: nil, deleted_at: Time.current)
    assert_equal [ banned.id, @bob.id ].sort, Game::DropFriendsAndTradesJob.players_with_ties.pluck(:id).sort

    assert_output(/no deleted or banned player/) { rake_task("game:drop_friends_and_trades").execute }

    assert_equal 0, ties_of(banned)
    assert_equal "cancelled", trade.reload.status
    assert_equal 0, holding(@alice, @portal).reserved
    assert friends?(@alice, @carol)
    assert_empty Game::DropFriendsAndTradesJob.players_with_ties
  end

  test "the sweep reports a player whose release fails and goes on; the task then fails with the count left" do
    banned = accounts_players(:banned)
    befriend(banned, @alice)
    @bob.update_columns(banned_at: Time.current)
    drop = Game::DropFriendsAndTrades.new
    Game::DropFriendsAndTrades.define_singleton_method(:new) do
      Object.new.tap do |operation|
        operation.define_singleton_method(:call) do |player:|
          raise "the release failed" if player.id == banned.id

          drop.call(player:)
        end
      end
    end
    begin
      assert_error_reported(RuntimeError) do
        _, err = capture_io { assert_raises(SystemExit) { rake_task("game:drop_friends_and_trades").execute } }
        assert_match(/1 deleted or banned player\(s\) still have/, err)
      end
    ensure
      Game::DropFriendsAndTrades.singleton_class.remove_method(:new)
    end

    assert_equal [ banned.id ], Game::DropFriendsAndTradesJob.players_with_ties.pluck(:id)
    assert_equal 0, ties_of(@bob)
  end

  def flaky_cancel(failures:)
    attempts = 0
    operation = Game::CancelOpenTrades.new
    lock = operation.method(:lock_open_trades)
    operation.define_singleton_method(:lock_open_trades) do |player|
      attempts += 1
      raise ActiveRecord::Deadlocked, "deadlock detected" if attempts <= failures

      lock.call(player)
    end
    [ operation, -> { attempts } ]
  end

  test "a deadlock aborts one attempt at cancelling the open trades, which tries again inside the drop's transaction, keeping every tie dropped once" do
    trade = propose(@alice, @bob, { @portal => 2 }, { @depths => 1 })
    cancel, attempts = flaky_cancel(failures: 1)
    Game::CancelOpenTrades.define_singleton_method(:new) { cancel }
    begin
      assert Game::DropFriendsAndTrades.new.call(player: @bob).success?
    ensure
      Game::CancelOpenTrades.singleton_class.remove_method(:new)
    end

    assert_equal 2, attempts.call
    assert_equal "cancelled", trade.reload.status
    assert_equal [ 3, 0 ], holding(@alice, @portal).slice(:quantity, :reserved).values
    assert_not friends?(@alice, @bob)
  end

  test "a deadlock that keeps coming is raised after the attempts" do
    cancel, attempts = flaky_cancel(failures: Game::CancelOpenTrades::ATTEMPTS)

    assert_raises(ActiveRecord::Deadlocked) { cancel.call(player: @bob) }
    assert_equal Game::CancelOpenTrades::ATTEMPTS, attempts.call
  end
end
