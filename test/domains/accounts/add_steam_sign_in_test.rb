require "test_helper"

class Accounts::AddSteamSignInTest < ActiveSupport::TestCase
  STEAM_ID = "76561197960287930".freeze

  setup do
    @player = Accounts::Player.create!(persona_name: "brave-otter-12")
    @player.identities.create!(provider: "discord", uid: "discord-1")
  end

  def link(steam_id = STEAM_ID, player: @player, persona_name: "Gabe")
    Accounts::AddSteamSignIn.new.call(player:, steam_id:, persona_name:)
  end

  def added_events
    Rails.configuration.event_store.read.of_type(Accounts::IdentityAdded).to_a
  end

  test "the Steam identity joins the player, with its Steam id, its Steam name and one IdentityAdded" do
    assert_equal @player, link.value!

    @player.reload
    assert_predicate @player.identities.where(provider: "steam", uid: STEAM_ID), :exists?
    assert_equal STEAM_ID, @player.steam_id
    assert_equal "Gabe", @player.persona_name
    assert_equal [ { player_id: @player.id, provider: "steam" } ], added_events.map(&:data)
  end

  test "a name Steam did not give keeps the player's name" do
    link(persona_name: nil).value!

    assert_equal "brave-otter-12", @player.reload.persona_name
  end

  test "linking again the Steam id the player holds succeeds without a write" do
    link.value!

    assert_no_difference -> { Accounts::Identity.count } do
      assert_equal @player, link(persona_name: "Other").value!
    end
    assert_equal "Gabe", @player.reload.persona_name
    assert_equal 1, added_events.size
  end

  test "a Steam id held by another player's identity is refused and nothing is linked" do
    taken = accounts_players(:player).identities.find_by!(provider: "steam").uid

    assert_no_difference -> { Accounts::Identity.count } do
      assert_equal Dry::Monads::Failure(:steam_taken), link(taken)
    end
    assert_nil @player.reload.steam_id
    assert_empty added_events
  end

  test "a Steam id another player holds from before identities is refused" do
    other = Accounts::Player.create!(steam_id: STEAM_ID)

    assert_equal Dry::Monads::Failure(:steam_taken), link
    assert_not @player.identities.exists?(provider: "steam")
    assert_nil other.reload.identities.find_by(provider: "steam")
  end

  test "a player who holds another Steam id from before identities is refused and keeps it" do
    @player.update_columns(steam_id: "76561197960287931")

    assert_equal :identity_taken, link.failure
    assert_equal "76561197960287931", @player.reload.steam_id
    assert_not @player.identities.exists?(provider: "steam")
  end

  test "a removed or missing player is refused" do
    assert_equal Dry::Monads::Failure(:player_required), link(player: nil)
    assert_equal Dry::Monads::Failure(:player_required), link(player: accounts_players(:banned))
    assert_empty added_events
  end
end
