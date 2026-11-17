require "test_helper"

class DuelSeatChannelTest < ActionCable::Channel::TestCase
  include ActiveJob::TestHelper

  setup do
    @player = accounts_players(:player)
    @seat = Game::DuelSeat.create!(duel: Game::Duel.create!, role: "challenger", player_id: @player.id, status: "seated").reload
  end

  def signed(*streamables) = Turbo::StreamsChannel.signed_stream_name(streamables)

  test "the seat's player subscribes to its stream in each locale" do
    stub_connection current_player: @player

    %i[en fr].each do |locale|
      subscribe signed_stream_name: signed(*DuelStream.streamables(@seat.stream_key, locale))

      assert subscription.confirmed?
      assert_has_stream DuelStream.streamables(@seat.stream_key, locale).join(":")
    end
  end

  test "another player is refused the seat's stream" do
    stub_connection current_player: accounts_players(:moderator)

    subscribe signed_stream_name: signed(*DuelStream.streamables(@seat.stream_key, :en))

    assert subscription.rejected?
  end

  test "a visitor is refused the seat's stream" do
    stub_connection current_player: nil

    subscribe signed_stream_name: signed(*DuelStream.streamables(@seat.stream_key, :en))

    assert subscription.rejected?
  end

  test "a name in no available locale, of another kind, unsigned or of a seat left without its player is refused" do
    stub_connection current_player: @player

    [ signed("duel-seat", @seat.stream_key, "de"), signed(*PlayerStream.streamables(@player, :en)),
      DuelStream.streamables(@seat.stream_key, :en).join(":"), signed("duel-seat", SecureRandom.uuid, "en") ].each do |name|
      subscribe signed_stream_name: name

      assert subscription.rejected?, name
    end
  end

  test "subscribing leases the seat for 20 seconds and pushes the current board and connection slot to both seats" do
    stub_connection current_player: @player
    travel_to(Time.utc(2026, 11, 17, 12)) do
      assert_enqueued_with(job: DuelStreamJob, args: [ [ @seat.duel_id ] ]) do
        subscribe signed_stream_name: signed(*DuelStream.streamables(@seat.stream_key, :en))
      end

      assert_equal Time.current + 20.seconds, @seat.reload.present_until
    end
  end

  test "a refused subscription writes and pushes nothing" do
    stub_connection current_player: accounts_players(:moderator)

    assert_no_enqueued_jobs { subscribe signed_stream_name: signed(*DuelStream.streamables(@seat.stream_key, :en)) }
    assert_nil @seat.reload.present_until
  end

  test "a 10 second timer renews the lease, pushes only when it had lapsed, and leaving writes nothing" do
    stub_connection current_player: @player
    renew, options = DuelSeatChannel.periodic_timers.sole
    assert_equal 10.seconds, options[:every]

    travel_to(Time.utc(2026, 11, 17, 12)) do
      subscribe signed_stream_name: signed(*DuelStream.streamables(@seat.stream_key, :en))
      clear_enqueued_jobs

      travel 10.seconds
      assert_no_enqueued_jobs { subscription.instance_exec(&renew) }
      assert_equal Time.current + 20.seconds, @seat.reload.present_until

      travel 30.seconds
      assert_enqueued_with(job: DuelStreamJob, args: [ [ @seat.duel_id ] ]) { subscription.instance_exec(&renew) }
      assert_equal Time.current + 20.seconds, @seat.reload.present_until

      travel 5.seconds
      expected = @seat.reload.present_until
      unsubscribe
      assert_equal expected, @seat.reload.present_until
    end
  end
end
