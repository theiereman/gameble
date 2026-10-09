require "test_helper"

class PlayerStreamTest < ActiveSupport::TestCase
  include ActionCable::TestHelper
  include ActiveJob::TestHelper

  setup do
    @alice = accounts_players(:player)
    @bob = accounts_players(:moderator)
    @one = catalog_card_seasons(:portal_one).id
    @three = catalog_card_seasons(:rare_card_one).id
    low, high = [ @alice.id, @bob.id ].minmax
    Game::Friendship.create!(low_player_id: low, high_player_id: high)
    Game::Holding.create!(player_id: @alice.id, card_season_id: @one, quantity: 3, reserved: 0)
    Game::Holding.create!(player_id: @bob.id, card_season_id: @three, quantity: 2, reserved: 0)
  end

  def propose(player = @alice, recipient = @bob)
    Game::ProposeTrade.new.call(player:, recipient:, offer: { @one => 1 }, request: { @three => 1 })
  end

  def trades_for(*players) = players.map { { player_id: it.id, topic: "trades" } }

  def stream_jobs = enqueued_jobs.select { it[:job] == PlayerStreamJob }

  def batches = ActiveSupport::IsolatedExecutionState[PlayerStream::BATCHES] || {}

  test "a proposal enqueues one job after its commit, with a notice for each party" do
    assert_enqueued_with(job: PlayerStreamJob, args: [ trades_for(@alice, @bob) ]) { assert propose.success? }
    assert_equal 1, stream_jobs.size
    assert_empty batches
  end

  test "every trade event tells both parties" do
    data = { trade_id: 1, proposer_id: @alice.id, recipient_id: @bob.id }

    PlayerStream::TRADE_EVENTS.each do |type|
      assert_equal trades_for(@alice, @bob), PlayerStream.notices(type.new(data:)), type.name
    end
  end

  test "an invitation tells both players, and its acceptance names the accepting friend to the sender" do
    data = { invitation_id: 1, sender_id: @alice.id, recipient_id: @bob.id }

    assert_equal [ { player_id: @alice.id, topic: "friends" }, { player_id: @bob.id, topic: "friends" } ],
      PlayerStream.notices(Game::InvitationSent.new(data:))
    assert_equal [ { player_id: @alice.id, topic: "friends", friend_id: @bob.id }, { player_id: @bob.id, topic: "friends" } ],
      PlayerStream.notices(Game::InvitationAccepted.new(data:))
  end

  test "other events tell nothing" do
    assert_empty PlayerStream.notices(Game::PackOpened.new(data: { player_id: @alice.id, pack_id: 1 }))
  end

  test "sending and accepting an invitation enqueue their notices" do
    stranger = accounts_players(:administrator)

    assert_enqueued_with(job: PlayerStreamJob, args: [ [ { player_id: stranger.id, topic: "friends" }, { player_id: @alice.id, topic: "friends" } ] ]) do
      Game::SendInvitation.new.call(player: stranger, code: "7K2Q-F3NX").value!
    end
    invitation = Game::Invitation.pending.find_by!(sender_id: stranger.id)
    assert_enqueued_with(job: PlayerStreamJob,
      args: [ [ { player_id: stranger.id, topic: "friends", friend_id: @alice.id }, { player_id: @alice.id, topic: "friends" } ] ]) do
      Game::AcceptInvitation.new.call(player: @alice, token: invitation.token).value!
    end
  end

  test "a refused operation enqueues nothing" do
    assert_no_enqueued_jobs(only: PlayerStreamJob) do
      assert propose(@alice, accounts_players(:administrator)).failure?
    end
  end

  test "the notices of one transaction leave together once it commits, and nothing is broadcast inside it" do
    perform_enqueued_jobs(only: PlayerStreamJob) do
      ApplicationRecord.transaction do
        trade = propose.value!
        Game::CancelTrade.new.call(player: @alice, trade_id: trade.id).value!

        assert_empty stream_jobs, "nothing is enqueued before the commit"
        assert_no_broadcasts PlayerStream.name(@bob, :en)
      end
    end

    performed = performed_jobs.select { it[:job] == PlayerStreamJob }
    assert_equal 1, performed.size
    assert_equal [ trades_for(@alice, @bob) * 2 ], ActiveJob::Arguments.deserialize(performed.sole[:args])
    assert_broadcasts PlayerStream.name(@bob, :en), 1
    assert_broadcasts PlayerStream.name(@bob, :fr), 1
    assert_empty batches
  end

  test "a transaction rolled back leaves nothing" do
    ApplicationRecord.transaction do
      assert propose.success?
      raise ActiveRecord::Rollback
    end

    assert_empty stream_jobs
    assert_empty batches
    assert_not Game::Trade.exists?
  end

  test "deleting a player tells their trade partners and friends, found before they are dropped" do
    propose.value!
    stranger = accounts_players(:administrator)
    Game::SendInvitation.new.call(player: stranger, code: "7K2Q-F3NX").value!
    clear_enqueued_jobs

    assert Accounts::DeletePlayer.new.call(player: @alice).success?

    expected = [ { player_id: @bob.id, topic: "trades" }, { player_id: @bob.id, topic: "friends" }, { player_id: stranger.id, topic: "friends" } ]
    assert_equal [ expected ], stream_jobs.map { ActiveJob::Arguments.deserialize(it[:args]).first }
    assert_equal "cancelled", Game::Trade.sole.status
  end

  test "deleting a player tells a stranger whose invitation they ignored, still pending on the stranger's side" do
    propose.value!
    stranger = accounts_players(:administrator)
    invitation = Game::SendInvitation.new.call(player: stranger, code: "7K2Q-F3NX").value!
    Game::IgnoreInvitation.new.call(player: @alice, token: invitation.token).value!
    clear_enqueued_jobs

    assert Accounts::DeletePlayer.new.call(player: @alice).success?

    expected = [ { player_id: @bob.id, topic: "trades" }, { player_id: @bob.id, topic: "friends" }, { player_id: stranger.id, topic: "friends" } ]
    assert_equal [ expected ], stream_jobs.map { ActiveJob::Arguments.deserialize(it[:args]).first }
  end

  test "going private tells the player and their trade partners on either side, found before the trades are cancelled" do
    carol = accounts_players(:administrator)
    low, high = [ @alice.id, carol.id ].minmax
    Game::Friendship.create!(low_player_id: low, high_player_id: high)
    Game::Holding.create!(player_id: carol.id, card_season_id: @three, quantity: 1, reserved: 0)
    propose.value!
    Game::ProposeTrade.new.call(player: carol, recipient: @alice, offer: { @three => 1 }, request: { @one => 1 }).value!
    clear_enqueued_jobs

    assert Accounts::SetVisibility.new.call(player: @alice, visibility: "private").success?

    notices = stream_jobs.map { ActiveJob::Arguments.deserialize(it[:args]).first }.sole
    assert_equal trades_for(@alice, @bob, carol).sort_by { it[:player_id] }, notices.sort_by { it[:player_id] }
    assert_equal %w[cancelled cancelled], Game::Trade.pluck(:status)
  end

  test "going friends only or public tells no one" do
    propose.value!
    clear_enqueued_jobs

    Accounts::SetVisibility.new.call(player: @alice, visibility: "friends_only").value!

    assert_empty stream_jobs
  end

  test "a ban tells the banned player's friends" do
    banned = Accounts::PlayerBanned.new(data: { player_id: @alice.id })

    assert_enqueued_with(job: PlayerStreamJob, args: [ [ { player_id: @bob.id, topic: "friends" } ] ]) do
      ApplicationRecord.transaction do
        @alice.update!(banned_at: Time.current)
        Rails.configuration.event_store.publish(banned, stream_name: "Accounts::Player-#{@alice.id}")
      end
    end
    assert_not Game::Friendship.of(@alice.id).exists?
  end
end
