require "test_helper"

class SetRowsHelperTest < ActionView::TestCase
  def standing(held:, total:, tiers:) = Game::SetStanding.measured(set_id: 1, held:, total:, tiers:)

  def path(held, total: 160, tiers: { "bronze" => 40, "silver" => 80, "gold" => 110, "master" => 130 })
    set_tier_path(standing(held:, total:, tiers:)).map { [ it.tier, it.state, it.required, it.lit ] }
  end

  test "the tier path lights each stretch between two tiers as the cards go from the one's count to the other's" do
    assert_equal [ [ "bronze", :reached, 40, nil ], [ "silver", :reached, 80, 100 ], [ "gold", :next, 110, 67 ],
      [ "master", :later, 130, 0 ], [ "complete", :later, 160, 0 ] ], path(100)
  end

  test "the line is unlit before the first tier and lit to the end once the set is complete" do
    assert_equal [ nil, 0, 0, 0, 0 ], path(12).map(&:last)
    assert_equal [ nil, 100, 100, 100, 100 ], path(160).map(&:last)
  end

  test "a three-digit count is the tier's required figure as it is, never a negative number" do
    path = set_tier_path(standing(held: 150, total: 160, tiers: { "bronze" => 40, "silver" => 80, "gold" => 110, "master" => 130 }))

    assert_equal [ 40, 80, 110, 130, 160 ], path.map(&:required)
    assert path.all? { it.required.positive? && it.lit.to_i.between?(0, 100) }
  end

  test "a tier asking as many cards as the one before it is lit all or nothing, never divided by zero" do
    tiers = { "bronze" => 40, "gold" => 160 }

    assert_equal [ nil, 50, 0 ], path(100, tiers:).map(&:last)
    assert_equal [ nil, 100, 100 ], path(160, tiers:).map(&:last)
  end

  test "a set with only the complete tier is one node, with no line leading to it" do
    assert_equal [ [ "complete", :next, 3, nil ] ], path(2, total: 3, tiers: {})
  end
end
