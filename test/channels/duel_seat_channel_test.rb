require "test_helper"

class DuelSeatChannelTest < ActionCable::Channel::TestCase
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
end
