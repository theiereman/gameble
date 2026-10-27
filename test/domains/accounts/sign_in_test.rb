require "test_helper"

class Accounts::SignInTest < ActiveSupport::TestCase
  STEAM_ID = "76561197960287930".freeze

  # Fixture players exist; a failed sign-in adds none.
  def assert_no_new_player
    assert_equal 0, Accounts::Player.where.not(id: accounts_players.map(&:id)).count
  end

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
    assert_equal 1, Accounts::Player.where(steam_id: STEAM_ID).count
    assert_equal 1, registered_events.size
  end

  test "only a sign-up leaves the welcome pending: a player from before, or one who closed it, signs in without it" do
    player = Accounts::SignIn.new.call(steam_id: STEAM_ID).value!
    assert_predicate player.reload, :welcome_pending

    Accounts::CloseWelcome.new.call(player_id: player.id).value!
    assert_not Accounts::SignIn.new.call(steam_id: STEAM_ID).value!.reload.welcome_pending

    existing = accounts_players(:player)
    assert_not Accounts::SignIn.new.call(steam_id: existing.steam_id).value!.welcome_pending
    assert_not existing.reload.welcome_pending
  end

  test "a sign-in notes the visit at once" do
    player = Accounts::SignIn.new.call(steam_id: STEAM_ID).value!
    player.update_columns(last_seen_at: 4.years.ago)

    travel_to(Time.utc(2026, 10, 9, 4)) { Accounts::SignIn.new.call(steam_id: STEAM_ID).value! }

    assert_equal Time.utc(2026, 10, 9, 4), player.reload.last_seen_at
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

    assert_equal 1, Accounts::Player.where(steam_id: STEAM_ID).count
    assert_empty registered_events
  end

  [ nil, "", "7656119796028793", "765611979602879300", "7656119796028793a", " 76561197960287930", 76561197960287930 ].each do |steam_id|
    test "a malformed Steam id #{steam_id.inspect} fails with invalid_steam_id and writes nothing" do
      result = Accounts::SignIn.new.call(steam_id: steam_id)

      assert result.failure?
      assert_equal :invalid_steam_id, result.failure
      assert_no_new_player
      assert_empty registered_events
    end
  end

  test "a banned player is refused with banned and nothing is published" do
    banned = accounts_players(:banned)

    result = Accounts::SignIn.new.call(steam_id: banned.steam_id)

    assert result.failure?
    assert_equal :banned, result.failure
    assert_empty registered_events
  end

  test "every failure code has a message in both locales" do
    %i[en fr].each do |locale|
      I18n.with_locale(locale) do
        %i[invalid_steam_id banned].each { |code| assert_predicate Accounts::SignIn.failure_message(code), :present? }
      end
    end
  end

  # The persona name

  test "a first sign-in stores the persona name and still publishes PlayerRegistered" do
    player = Accounts::SignIn.new.call(steam_id: STEAM_ID, persona_name: "Gabe").value!

    assert_equal "Gabe", player.reload.persona_name
    assert_equal [ { player_id: player.id } ], registered_events.map(&:data)
  end

  test "a later sign-in with another name renames the player" do
    Accounts::SignIn.new.call(steam_id: STEAM_ID, persona_name: "Gabe")

    player = Accounts::SignIn.new.call(steam_id: STEAM_ID, persona_name: "Gaben").value!

    assert_equal "Gaben", player.reload.persona_name
    assert_equal 1, registered_events.size
  end

  [ nil, "", "   ", 42 ].each do |name|
    test "a sign-in with a persona name of #{name.inspect} keeps the stored one" do
      Accounts::SignIn.new.call(steam_id: STEAM_ID, persona_name: "Gabe")

      result = Accounts::SignIn.new.call(steam_id: STEAM_ID, persona_name: name)

      assert result.success?
      assert_equal "Gabe", result.value!.reload.persona_name
    end
  end

  test "a first sign-in without a name leaves none" do
    player = Accounts::SignIn.new.call(steam_id: STEAM_ID).value!

    assert_nil player.reload.persona_name
  end

  test "the name is stripped and cut to 64 characters" do
    player = Accounts::SignIn.new.call(steam_id: STEAM_ID, persona_name: "  #{"a" * 70}  ").value!

    assert_equal "a" * 64, player.reload.persona_name
  end

  test "the same name writes nothing" do
    player = Accounts::SignIn.new.call(steam_id: STEAM_ID, persona_name: "Gabe").value!
    updated_at = player.reload.updated_at

    travel 1.minute do
      Accounts::SignIn.new.call(steam_id: STEAM_ID, persona_name: " Gabe ")
    end

    assert_equal updated_at, player.reload.updated_at
  end

  test "control characters are dropped from the name, a NUL byte included, and the sign-in goes on" do
    result = Accounts::SignIn.new.call(steam_id: STEAM_ID, persona_name: "Ga\u0000be\n")

    assert result.success?
    assert_equal "Gabe", result.value!.reload.persona_name
  end

  # Invisible characters.

  [ "\u200B\u202E", "\u3164", "\u2066 \u3000" ].each do |name|
    test "a first sign-in with a persona name of #{name.inspect}, nothing visible, stores none" do
      result = Accounts::SignIn.new.call(steam_id: STEAM_ID, persona_name: name)

      assert result.success?
      assert_nil result.value!.reload.persona_name
    end

    test "a later sign-in with a persona name of #{name.inspect} keeps the stored one" do
      Accounts::SignIn.new.call(steam_id: STEAM_ID, persona_name: "Gabe")

      assert_equal "Gabe", Accounts::SignIn.new.call(steam_id: STEAM_ID, persona_name: name).value!.reload.persona_name
    end
  end

  { "Ga\u200Bbe" => "Gabe", "\u202Egabe" => "gabe", "A\u3000B" => "A B" }.each do |name, stored|
    test "a persona name of #{name.inspect} is stored as #{stored.inspect}" do
      player = Accounts::SignIn.new.call(steam_id: STEAM_ID, persona_name: name).value!

      assert_equal stored, player.reload.persona_name
    end
  end

  test "a banned player's name is not stored" do
    banned = accounts_players(:banned)

    result = Accounts::SignIn.new.call(steam_id: banned.steam_id, persona_name: "Banned Brother")

    assert_equal :banned, result.failure
    assert_nil banned.reload.persona_name
  end
end
