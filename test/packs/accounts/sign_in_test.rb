require "test_helper"

class Accounts::SignInTest < ActiveSupport::TestCase
  STEAM_ID = "76561197960287930".freeze

  def registered_events
    Rails.configuration.event_store.read.of_type(Accounts::PlayerRegistered).to_a
  end

  test "a first sign-in creates a player with a token and publishes PlayerRegistered with its id only" do
    result = Accounts::SignIn.new.call(steam_id: STEAM_ID)

    assert result.success?
    player = result.value!
    assert_equal STEAM_ID, player.reload.steam_id
    assert_predicate player.token, :present?

    events = Rails.configuration.event_store.read.stream("Accounts::Player$#{player.id}").to_a
    assert_equal 1, events.size
    assert_instance_of Accounts::PlayerRegistered, events.first
    assert_equal({ player_id: player.id }, events.first.data)
  end

  test "a returning sign-in reuses the player and publishes nothing" do
    first = Accounts::SignIn.new.call(steam_id: STEAM_ID).value!

    result = Accounts::SignIn.new.call(steam_id: STEAM_ID)

    assert result.success?
    assert_equal first.id, result.value!.id
    assert_equal 1, Accounts::Player.count
    assert_equal 1, registered_events.size
  end

  test "a player created by a concurrent sign-in is reused through the unique index" do
    Accounts::Player.create!(steam_id: STEAM_ID)
    # The lookup misses, as if the other sign-in committed just after it.
    Accounts::Player.define_singleton_method(:find_by) { |*| nil }
    begin
      result = Accounts::SignIn.new.call(steam_id: STEAM_ID)
    ensure
      Accounts::Player.singleton_class.remove_method(:find_by)
    end

    assert result.success?
    assert_not result.value!.previously_new_record?

    assert_equal 1, Accounts::Player.count
    assert_empty registered_events
  end

  [ nil, "", "7656119796028793", "765611979602879300", "7656119796028793a", " 76561197960287930", 76561197960287930 ].each do |steam_id|
    test "a malformed Steam id #{steam_id.inspect} fails with invalid_steam_id and writes nothing" do
      result = Accounts::SignIn.new.call(steam_id: steam_id)

      assert result.failure?
      assert_equal :invalid_steam_id, result.failure
      assert_equal 0, Accounts::Player.count
      assert_empty registered_events
    end
  end

  test "every failure code has a message in both locales" do
    %i[en fr].each do |locale|
      I18n.with_locale(locale) { assert_predicate Accounts::SignIn.failure_message(:invalid_steam_id), :present? }
    end
  end
end
