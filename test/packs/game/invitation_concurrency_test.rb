require "test_helper"

class Game::InvitationConcurrencyTest < ActiveSupport::TestCase
  self.use_transactional_tests = false

  setup do
    @alice = accounts_players(:player)
    @bob = accounts_players(:moderator)
  end

  teardown { clean }

  def clean
    Game::Invitation.delete_all
    Game::Friendship.delete_all
    streams = [ @alice, @bob ].map { |player| Game::Operation.stream_name(player.id) }
    connection = ActiveRecord::Base.connection
    event_ids = connection.select_values(ActiveRecord::Base.sanitize_sql_array([ "SELECT event_id FROM event_store_events_in_streams WHERE stream IN (?)", streams ]))
    connection.exec_delete(ActiveRecord::Base.sanitize_sql_array([ "DELETE FROM event_store_events_in_streams WHERE stream IN (?)", streams ]))
    connection.exec_delete(ActiveRecord::Base.sanitize_sql_array([ "DELETE FROM event_store_events WHERE event_id IN (?)", event_ids ])) if event_ids.any?
  end

  def accepted_events
    [ @alice, @bob ].sum { |player| Rails.configuration.event_store.read.stream(Game::Operation.stream_name(player.id)).of_type([ Game::InvitationAccepted ]).count }
  end

  def invite(from, code)
    -> { Game::SendInvitation.new.call(player: Accounts::Player.find(from.id), code:) }
  end

  # A deadlock would hang the threads: a timeout fails the test instead.
  def together(*blocks)
    gate = Queue.new
    threads = blocks.map do |block|
      Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do
          gate.pop
          block.call
        end
      end
    end
    blocks.size.times { gate << :go }
    threads.map { |thread| thread.join(20) ? thread.value : flunk("a thread is stuck: deadlock") }
  end

  test "two players inviting each other at once become friends and leave no invitation pending" do
    10.times do
      results = together(invite(@alice, "8F2D-K9XM"), invite(@bob, "7K2Q-F3NX"))

      assert results.all?(&:success?), results.inspect
      assert Game::FriendshipBetween.call(@alice, @bob)
      assert_equal 0, Game::Invitation.pending.count
      assert_equal 1, accepted_events
      clean
    end
  end
end
