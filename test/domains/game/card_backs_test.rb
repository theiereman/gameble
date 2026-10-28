require "test_helper"
require_relative "../../support/game_packs"

class Game::CardBacksTest < ActiveSupport::TestCase
  include GamePacks

  setup do
    @player = accounts_players(:player)
    Game::CreatePlayerState.new.call(player: @player).value!
  end

  def choose(key, player: @player) = Game::PlayerState.where(player_id: player.id).update_all(active_card_back: key)
  def unlock(key, player: @player) = Game::CardBackUnlock.record(player.id, key, Time.current)

  test "the catalogue holds Standard, which needs no unlock row" do
    assert_equal [ "standard" ], Game::CardBacks::KEYS
    assert_equal :always, Game::CardBacks.find("standard").unlock.kind
    assert_nil Game::CardBacks.find("unknown")
  end

  test "a new account wears Standard" do
    assert_equal "standard", Game::CardBacks.active_key(@player)
  end

  test "a player without a state row wears Standard" do
    assert_equal "standard", Game::CardBacks.active_key(accounts_players(:moderator))
  end

  test "an unlocked chosen back is the active one, in one query" do
    unlock("aurore")
    choose("aurore")

    key = nil
    assert_queries_count(1) { key = Game::CardBacks.active_key(@player) }
    assert_equal "aurore", key
  end

  test "a chosen back that is not unlocked falls back to Standard" do
    choose("aurore")

    assert_equal "standard", Game::CardBacks.active_key(@player)
  end

  test "another player's unlock does not make a back active" do
    unlock("aurore", player: accounts_players(:moderator))
    choose("aurore")

    assert_equal "standard", Game::CardBacks.active_key(@player)
  end

  test "the opening stores the active back on the pack" do
    unlock("aurore")
    choose("aurore")
    create_pack(@player)

    Game::OpenPack.new.call(player: @player).value!

    assert_equal "aurore", Game::Pack.where(player_id: @player.id).where.not(opened_at: nil).order(:opened_at).last.card_back
  end
end
