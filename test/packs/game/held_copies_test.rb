require "test_helper"

class Game::HeldCopiesTest < ActiveSupport::TestCase
  setup do
    @player = accounts_players(:player)
    @portal, @common, @legendary = %i[portal_one common_card_one legendary_card_one].map { catalog_card_seasons(it).id }
  end

  def hold(player, card_season_id, quantity, reserved: 0)
    Game::Holding.create!(player_id: player.id, card_season_id:, quantity:, reserved:)
  end

  test "each card held, its copies, reserved and free, in one query" do
    hold(@player, @portal, 3, reserved: 1)
    hold(@player, @common, 2, reserved: 2)
    hold(@player, @legendary, 0)
    hold(accounts_players(:moderator), @legendary, 4)

    held = nil
    assert_queries_count(1) { held = Game::HeldCopies.call(@player) }

    assert_equal [ @portal, @common ].sort, held.keys
    assert_equal [ 3, 1, 2 ], held.fetch(@portal).then { [ it.quantity, it.reserved, it.free ] }
    assert_equal 0, held.fetch(@common).free
  end

  test "another player can be asked about, a visitor holds nothing" do
    hold(accounts_players(:moderator), @legendary, 4)

    assert_equal [ @legendary ], Game::HeldCopies.call(accounts_players(:moderator)).keys
    assert_queries_count(0) { assert_equal({}, Game::HeldCopies.call(nil)) }
  end
end
