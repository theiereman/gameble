require "test_helper"

class Game::DuelStatMovesTest < ActiveSupport::TestCase
  def change(card_season_id, card_id, stat, from, to)
    Game::DuelProfiles::Change.new(card_season_id:, card_id:, stat:, from: BigDecimal(from.to_s), to: BigDecimal(to.to_s))
  end

  test "each card keeps its largest change, rises then falls, three of each at most, as one-decimal floats" do
    changes = [
      change(1, 10, :popularity, 50, 51), change(2, 10, :rating, 50, 40.5),
      change(3, 20, :release, 10, 30), change(4, 30, :circulation, 10, 25), change(5, 40, :discovery, 10, 12),
      change(6, 50, :popularity, 10, 11), change(7, 60, :popularity, 10, 10)
    ]

    moves = Game::DuelStatMoves.new(changes)

    assert_equal [ 3, 4, 5 ], moves.rises.map(&:card_season_id)
    assert_equal [ 2 ], moves.falls.map(&:card_season_id)
    assert_equal({ "card_season_id" => 2, "stat" => "rating", "from" => 50.0, "to" => 40.5 }, moves.rows.last)
    assert(moves.rows.all? { it["from"].is_a?(Float) && it["to"].is_a?(Float) })
  end

  test "no change, or none in whole percents, no move" do
    assert_empty Game::DuelStatMoves.new([ change(1, 10, :rating, 40, 40), change(2, 20, :rating, 50.2, 50.4), change(3, 30, :rating, 49.5, 50.4) ]).rows
  end

  test "two editions of one card with equally large changes of the same stat move by the lower card-season" do
    moves = Game::DuelStatMoves.new([ change(8, 10, :rating, 50, 40), change(7, 10, :rating, 40, 50) ])

    assert_equal [ [ 7, 40.0, 50.0 ] ], moves.rows.map { it.values_at("card_season_id", "from", "to") }
  end
end
