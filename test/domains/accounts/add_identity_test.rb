require "test_helper"

class Accounts::AddIdentityTest < ActiveSupport::TestCase
  setup { @player = accounts_players(:player) }

  def add(**arguments) = Accounts::AddIdentity.new.call(player: @player, **arguments)

  def added_events
    Rails.configuration.event_store.read.of_type(Accounts::IdentityAdded).to_a
  end

  test "it adds a free identity to the player and publishes IdentityAdded" do
    result = add(provider: "discord", uid: "d-1", email_hash: "abc")

    identity = result.value!
    assert_equal @player, identity.player
    assert_equal "abc", identity.email_hash
    assert_equal [ { player_id: @player.id, provider: "discord" } ], added_events.map(&:data)
  end

  test "an identity of another player is refused" do
    other = accounts_players(:moderator)
    other.identities.create!(provider: "discord", uid: "d-1")

    assert_equal Dry::Monads::Failure(:identity_taken), add(provider: "discord", uid: "d-1")
    assert_empty added_events
  end

  test "an identity the player holds already is refused" do
    add(provider: "discord", uid: "d-1")

    assert_equal Dry::Monads::Failure(:identity_taken), add(provider: "discord", uid: "d-1")
  end

  test "a second Steam identity is refused" do
    assert_equal Dry::Monads::Failure(:identity_taken), add(provider: "steam", uid: "76561197960287930")
    assert_equal [ "steam" ], @player.identities.where(provider: "steam").pluck(:provider)
  end

  test "an email hash of another player's identity is refused" do
    accounts_players(:moderator).identities.create!(provider: "google", uid: "g-1", email_hash: "abc")

    assert_equal Dry::Monads::Failure(:email_known_google), add(provider: "email", uid: "e-1", email_hash: "abc")
    assert_nil Accounts::Identity.find_by(provider: "email", uid: "e-1")
  end

  test "an email hash of the player's own identity is accepted" do
    @player.identities.create!(provider: "google", uid: "g-1", email_hash: "abc")

    assert add(provider: "email", uid: "e-1", email_hash: "abc").success?
  end

  test "an unknown provider or a blank uid is refused" do
    assert_equal Dry::Monads::Failure(:invalid_identity), add(provider: "twitter", uid: "x")
    assert_equal Dry::Monads::Failure(:invalid_identity), add(provider: "google", uid: "")
    assert_equal Dry::Monads::Failure(:invalid_identity), add(provider: "steam", uid: "123")
  end

  test "no player, an unsaved one and a banned one are refused" do
    [ nil, Accounts::Player.new, accounts_players(:banned) ].each do |player|
      assert_equal Dry::Monads::Failure(:player_required), Accounts::AddIdentity.new.call(player:, provider: "google", uid: "g-1")
    end
  end
end
