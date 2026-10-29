require "test_helper"

class Accounts::SignInThroughIdentityTest < ActiveSupport::TestCase
  STEAM_ID = "76561197960287930".freeze

  def sign_in(**arguments) = Accounts::SignInThroughIdentity.new.call(**arguments)

  def registered_events
    Rails.configuration.event_store.read.of_type(Accounts::PlayerRegistered).to_a
  end

  test "a known Steam id signs in the same player through its identity" do
    player = accounts_players(:player)

    result = sign_in(provider: "steam", uid: player.steam_id)

    assert_equal player, result.value!
    assert_equal 1, player.identities.where(provider: "steam", uid: player.steam_id).count
  end

  test "a first Steam sign-in creates the player, its steam identity and publishes PlayerRegistered" do
    player = sign_in(provider: "steam", uid: STEAM_ID).value!

    assert_equal STEAM_ID, player.reload.steam_id
    assert_equal [ [ "steam", STEAM_ID ] ], player.identities.pluck(:provider, :uid)
    assert_equal [ { player_id: player.id } ], registered_events.map(&:data)
  end

  test "a Steam player without an identity row gets one at sign-in" do
    player = Accounts::Player.create!(steam_id: STEAM_ID)

    assert_equal player, sign_in(provider: "steam", uid: STEAM_ID).value!
    assert_equal [ STEAM_ID ], player.identities.pluck(:uid)
    assert_empty registered_events
  end

  test "an unknown provider uid creates a player with a generated handle and no steam id" do
    player = sign_in(provider: "discord", uid: "d-1").value!.reload

    assert_nil player.steam_id
    assert_predicate player.persona_name, :present?
    assert_equal [ [ "discord", "d-1" ] ], player.identities.pluck(:provider, :uid)
    assert_equal [ { player_id: player.id } ], registered_events.map(&:data)
  end

  test "a returning provider sign-in reuses the player and publishes nothing more" do
    first = sign_in(provider: "google", uid: "g-1").value!

    assert_equal first, sign_in(provider: "google", uid: "g-1").value!
    assert_equal 1, registered_events.size
  end

  test "a provider sign-in keeps the handle whatever name is passed" do
    player = sign_in(provider: "google", uid: "g-1", persona_name: "Someone").value!

    assert_not_equal "Someone", player.reload.persona_name
  end

  test "a new identity whose email hash is known is refused and creates nothing" do
    sign_in(provider: "google", uid: "g-1", email_hash: "abc")
    before = Accounts::Player.count

    result = sign_in(provider: "discord", uid: "d-1", email_hash: "abc")

    assert_equal Dry::Monads::Failure(:email_known_google), result
    assert_equal before, Accounts::Player.count
    assert_nil Accounts::Identity.find_by(provider: "discord", uid: "d-1")
  end

  test "a known identity signs in whatever its email hash" do
    first = sign_in(provider: "google", uid: "g-1", email_hash: "abc").value!

    assert_equal first, sign_in(provider: "google", uid: "g-1", email_hash: "abc").value!
  end

  test "a banned player is refused through any identity" do
    banned = accounts_players(:banned)
    banned.identities.create!(provider: "discord", uid: "d-banned")

    assert_equal :banned, sign_in(provider: "steam", uid: banned.steam_id).failure
    assert_equal :banned, sign_in(provider: "discord", uid: "d-banned").failure
    assert_empty registered_events
  end

  [ nil, "", "7656119796028793", "7656119796028793a", 76561197960287930 ].each do |uid|
    test "a Steam uid of #{uid.inspect} fails with invalid_steam_id" do
      assert_equal Dry::Monads::Failure(:invalid_steam_id), sign_in(provider: "steam", uid:)
    end
  end

  [ [ "twitter", "x" ], [ nil, "x" ], [ "google", nil ], [ "google", "" ], [ "google", 12 ] ].each do |provider, uid|
    test "provider #{provider.inspect} with uid #{uid.inspect} fails with invalid_identity" do
      before = Accounts::Player.count

      assert_equal Dry::Monads::Failure(:invalid_identity), sign_in(provider:, uid:)
      assert_equal before, Accounts::Player.count
    end
  end

  test "every new failure code has a message in both locales" do
    %i[en fr].each do |locale|
      I18n.with_locale(locale) do
        %i[invalid_identity identity_taken email_known_discord email_known_email email_known_google].each do |code|
          assert_predicate Accounts::SignInThroughIdentity.failure_message(code), :present?
        end
      end
    end
  end
end
