require "test_helper"

class Game::CardBackShelfTest < ActiveSupport::TestCase
  setup do
    @player = accounts_players(:player)
  end

  def states = Game::CardBackShelf.call(@player).to_h { [ it.key, it.state ] }

  test "a new account has Standard active and every other back locked" do
    shelf = Game::CardBackShelf.call(@player)

    assert_equal Game::CardBacks::KEYS, shelf.map(&:key)
    assert_equal :active, states["standard"]
    assert_equal [ :locked ], states.except("standard").values.uniq
  end

  test "an unlocked back is offered and the chosen one is active" do
    Game::CardBackUnlock.record(@player.id, "set-theme-rpg", Time.current)

    assert_equal :unlocked, states["set-theme-rpg"]

    Game::ChooseCardBack.new.call(player: @player, back: "set-theme-rpg").value!

    assert_equal [ :active, :unlocked ], states.values_at("set-theme-rpg", "standard")
  end

  test "each row carries the unlock of the catalogue" do
    row = Game::CardBackShelf.call(@player).find { it.key == "set-theme-rpg" }

    assert_equal [ :set_tier, [ "theme", "rpg" ] ], [ row.unlock.kind, row.unlock.target ]
    assert_predicate row, :locked?
  end
end
