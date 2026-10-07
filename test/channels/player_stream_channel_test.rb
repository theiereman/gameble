require "test_helper"

class PlayerStreamChannelTest < ActionCable::Channel::TestCase
  setup do
    @player = accounts_players(:player)
  end

  def signed(*streamables) = Turbo::StreamsChannel.signed_stream_name(streamables)

  test "a player subscribes to their own stream in each locale" do
    stub_connection current_player: @player

    %i[en fr].each do |locale|
      subscribe signed_stream_name: signed(*PlayerStream.streamables(@player, locale))

      assert subscription.confirmed?
      assert_has_stream PlayerStream.name(@player, locale)
    end
  end

  test "another player's stream is refused" do
    stub_connection current_player: @player

    subscribe signed_stream_name: signed(*PlayerStream.streamables(accounts_players(:moderator), :en))

    assert subscription.rejected?
  end

  test "a visitor is refused a private stream" do
    stub_connection current_player: nil

    subscribe signed_stream_name: signed(*PlayerStream.streamables(@player, :en))

    assert subscription.rejected?
  end

  test "a name made before the key rotated is refused" do
    old = signed(*PlayerStream.streamables(@player, :en))
    @player.update!(banned_at: Time.current)
    @player.update!(banned_at: nil)
    stub_connection current_player: @player.reload

    subscribe signed_stream_name: old

    assert subscription.rejected?
  end

  test "an unsigned or tampered name is refused" do
    stub_connection current_player: @player

    subscribe signed_stream_name: PlayerStream.name(@player, :en)

    assert subscription.rejected?
  end

  test "the name is the one Turbo verifies from the page's signed name" do
    assert_equal PlayerStream.name(@player, :fr),
      Turbo::StreamsChannel.verified_stream_name(signed(*PlayerStream.streamables(@player, :fr)))
    assert_equal [ PlayerStream.name(@player, :en), PlayerStream.name(@player, :fr) ], PlayerStream.names(@player)
  end
end
