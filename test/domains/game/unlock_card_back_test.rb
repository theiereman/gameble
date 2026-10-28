require "test_helper"
require_relative "../../support/game_packs"

class Game::UnlockCardBackTest < ActiveSupport::TestCase
  include GamePacks

  def aurore
    Game::CardBacks::Back.new(key: "aurore", asset: "back-aurore", unlock: Game::CardBacks::Unlock.new(kind: :achievement, target: "three_complete_sets"))
  end

  setup do
    @player = accounts_players(:player)
  end

  def unlock(back = "aurore", player: @player, retroactive: false)
    with_catalogue_back { Game::UnlockCardBack.new.call(player:, back:, retroactive:) }
  end

  def unlocked(player = @player) = Game::CardBackUnlock.where(player_id: player.id).pluck(:back)

  def with_catalogue_back
    original = Game::CardBacks.method(:find)
    extra = aurore
    Game::CardBacks.define_singleton_method(:find) { |key| key.to_s == "aurore" ? extra : original.call(key) }
    yield
  ensure
    Game::CardBacks.define_singleton_method(:find, original)
  end

  test "an unlock writes one row and publishes one event" do
    assert_predicate unlock, :success?

    assert_equal [ "aurore" ], unlocked
    assert_equal [ { player_id: @player.id, back: "aurore" } ], game_events(@player, Game::CardBackUnlocked).map(&:data)
  end

  test "asked again, it writes and publishes nothing more" do
    unlock
    again = unlock

    assert_equal :already_unlocked, again.failure
    assert_equal [ "aurore" ], unlocked
    assert_equal 1, game_events(@player, Game::CardBackUnlocked).size
  end

  test "a retroactive unlock says so in its event" do
    unlock(retroactive: true)

    assert_equal [ true ], game_events(@player, Game::CardBackUnlocked).map { it.data[:retroactive] }
  end

  test "Standard needs no row and an unknown back is refused" do
    assert_equal :already_unlocked, unlock("standard").failure
    assert_equal :unknown_back, unlock("nowhere").failure
    assert_empty unlocked
    assert_empty game_events(@player, Game::CardBackUnlocked)
  end

  test "a banned player is refused" do
    banned = accounts_players(:banned)

    assert_equal :player_required, unlock(player: banned).failure
    assert_empty unlocked(banned)
  end

  test "each player unlocks a back for themselves" do
    unlock
    unlock(player: accounts_players(:moderator))

    assert_equal [ [ "aurore" ], [ "aurore" ] ], [ unlocked, unlocked(accounts_players(:moderator)) ]
  end
end
