require "test_helper"
require_relative "../../support/game_packs"
require_relative "../../support/custom_sets"

# The Steam library set erased when its player turns the sync off: the set
# and its games go, the player's custom sets and other players' library sets
# stay, and the erase publishes nothing of its own.
class Game::EraseLibrarySetTest < ActiveSupport::TestCase
  include GamePacks
  include CustomSets

  setup { @player = accounts_players(:player) }

  def erase(player: @player) = Game::EraseLibrarySet.new.call(player:)

  test "it deletes the player's library set and its games, and nothing else" do
    library_set = create_library_set(@player)
    custom_set = create_custom_set(@player)
    theirs = create_library_set(accounts_players(:moderator))
    events = Rails.configuration.event_store.read.count

    assert_predicate erase, :success?

    assert_not Game::CustomSet.exists?(library_set.id)
    assert_equal 0, Game::CustomSetGame.where(custom_set_id: library_set.id).count
    assert_equal 3, Game::CustomSetGame.where(custom_set_id: custom_set.id).count
    assert_equal 3, Game::CustomSetGame.where(custom_set_id: theirs.id).count
    assert_equal events, Rails.configuration.event_store.read.count
  end

  test "a player with no library set succeeds with nothing to erase" do
    assert_predicate erase, :success?
  end

  test "a banned player's set is erased too; no player or an unsaved one is refused" do
    banned = accounts_players(:banned)
    library_set = create_library_set(banned)

    assert_predicate erase(player: banned), :success?
    assert_not Game::CustomSet.exists?(library_set.id)
    assert_equal :player_required, erase(player: nil).failure
    assert_equal :player_required, erase(player: Accounts::Player.new).failure
  end

  test "a sync that runs after the erase finds no set and writes nothing" do
    token = create_library_set(@player).token
    erase.value!

    assert_no_difference(-> { Game::CustomSet.count + Rails.configuration.event_store.read.count }) do
      assert_nil Game::SyncLibrarySet.new.call(player: @player, token:, card_ids: fixture_card_ids).value!
    end
  end
end
