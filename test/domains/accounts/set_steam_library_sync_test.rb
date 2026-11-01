require "test_helper"
require_relative "../../support/custom_sets"

class Accounts::SetSteamLibrarySyncTest < ActiveSupport::TestCase
  include CustomSets

  setup { @player = accounts_players(:player) }

  def set(enabled, player: @player) = Accounts::SetSteamLibrarySync.new.call(player:, enabled:)

  def sync_events(player = @player)
    Rails.configuration.event_store.read.stream("Accounts::Player$#{player.id}").of_type(Accounts::SteamLibrarySyncChanged).to_a
  end

  def writes = Accounts::Player.maximum(:updated_at).to_f + Rails.configuration.event_store.read.count + Game::CustomSet.count

  test "a new player has the sync on" do
    assert Accounts::Player.new.steam_library_sync
    assert @player.steam_library_sync
  end

  test "turning it off stores it and publishes the player and the new value" do
    assert_equal @player, set(false).value!

    assert_not @player.reload.steam_library_sync
    assert_equal [ { player_id: @player.id, enabled: false } ], sync_events.map { it.data.symbolize_keys }
  end

  test "turning it on again stores it and publishes once more" do
    set(false).value!

    assert_equal @player, set(true).value!

    assert @player.reload.steam_library_sync
    assert_equal [ false, true ], sync_events.map { it.data.fetch(:enabled) }
  end

  test "setting the value the player already has writes nothing and publishes nothing" do
    assert_no_difference(-> { writes }) { assert_equal @player, set(true).value! }

    set(false).value!
    assert_no_difference(-> { writes }) { assert_equal @player, set(false).value! }
    assert_equal 1, sync_events.size
  end

  [ nil, "", "on", "true", 1, 0, [ true ] ].each do |enabled|
    test "#{enabled.inspect} is refused and changes nothing" do
      assert_no_difference(-> { writes }) { assert_equal Dry::Monads::Failure(:invalid_setting), set(enabled) }
      assert @player.reload.steam_library_sync
    end
  end

  test "no player, an unsaved player and a banned one are refused" do
    assert_no_difference(-> { writes }) do
      assert_equal Dry::Monads::Failure(:player_required), set(false, player: nil)
      assert_equal Dry::Monads::Failure(:player_required), set(false, player: Accounts::Player.new)
      assert_equal Dry::Monads::Failure(:player_required), set(false, player: accounts_players(:banned))
    end
  end

  test "a player without a Steam identity is refused and nothing is written" do
    @player.identities.where(provider: "steam").delete_all

    assert_no_difference(-> { writes }) { assert_equal Dry::Monads::Failure(:steam_identity_required), set(false) }
    assert @player.reload.steam_library_sync
  end

  test "a failure has a message in both locales" do
    %i[en fr].each do |locale|
      I18n.with_locale(locale) do
        %i[invalid_setting steam_identity_required player_required].each do |code|
          assert_not_includes Accounts::SetSteamLibrarySync.failure_message(code), "translation missing"
        end
      end
    end
  end

  test "turning it off erases the library set and its games in the same change, and nothing else" do
    library_set = create_library_set(@player)
    custom_set = create_custom_set(@player)
    theirs = create_library_set(accounts_players(:moderator))

    set(false).value!

    assert_not Game::CustomSet.exists?(library_set.id)
    assert_not Game::CustomSetGame.exists?(custom_set_id: library_set.id)
    assert Game::CustomSet.exists?(custom_set.id)
    assert_equal 3, Game::CustomSetGame.where(custom_set_id: theirs.id).count
  end

  test "turning it on erases nothing" do
    library_set = create_library_set(@player)
    @player.update_column(:steam_library_sync, false)

    set(true).value!

    assert Game::CustomSet.exists?(library_set.id)
  end

  test "a player loaded while off and turned on elsewhere since reports no change" do
    @player.update_column(:steam_library_sync, false)
    stale = Accounts::Player.find(@player.id)
    @player.update_column(:steam_library_sync, true)

    player = set(true, player: stale).value!

    assert_not player.saved_change_to_steam_library_sync?
    assert_empty sync_events
  end

  test "a player loaded while on and turned off elsewhere since reports the change to on" do
    stale = Accounts::Player.find(@player.id)
    @player.update_column(:steam_library_sync, false)

    player = set(true, player: stale).value!

    assert_predicate player, :saved_change_to_steam_library_sync?
    assert player.steam_library_sync
    assert_equal [ true ], sync_events.map { it.data.fetch(:enabled) }
  end
end
