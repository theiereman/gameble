module Game
  module LuckOdds
    POINTS = { 1 => 0, 2 => 1, 3 => 5, 4 => 20, 5 => 100 }.freeze

    Expectation = Data.define(:points, :variance) do
      def +(other) = Expectation.new(points: points + other.points, variance: variance + other.variance)
      def *(count) = Expectation.new(points: points * count, variance: variance * count)
      def second_moment = variance + points**2
    end

    def self.points(tier) = POINTS.fetch(tier)

    def self.of(kind) = EXPECTATIONS.fetch(kind.to_s)

    def self.card(odds)
      total = odds.values.sum.to_f
      mean = odds.sum { |tier, weight| POINTS.fetch(tier) * weight } / total
      square = odds.sum { |tier, weight| POINTS.fetch(tier)**2 * weight } / total
      Expectation.new(points: mean, variance: square - mean**2)
    end

    def self.with_guarantee(odds, min_tier:, floor_odds:)
      below = odds.select { |tier, _| tier < min_tier }
      none_at_floor = (below.values.sum.fdiv(DrawOdds::TOTAL))**Pack::SIZE
      drawn = card(odds) * Pack::SIZE
      all_below = card(below) * Pack::SIZE
      one_redrawn = card(below) * (Pack::SIZE - 1) + card(floor_odds)

      mean = drawn.points + none_at_floor * (one_redrawn.points - all_below.points)
      square = drawn.second_moment + none_at_floor * (one_redrawn.second_moment - all_below.second_moment)
      Expectation.new(points: mean, variance: square - mean**2)
    end

    private_class_method :card, :with_guarantee

    EXPECTATIONS = {
      "regular" => card(DrawOdds::REGULAR) * Pack::SIZE,
      "bonus" => card(DrawOdds::BONUS) * Pack::BONUS_SIZE,
      "reward" => with_guarantee(DrawOdds::REWARD, min_tier: RewardDraw::MIN_TIER, floor_odds: DrawOdds::EPIC_OR_BETTER),
      "regular_with_guarantee" => with_guarantee(DrawOdds::REGULAR, min_tier: FirstSessionGuarantee::MIN_TIER, floor_odds: DrawOdds::GUARANTEE)
    }.freeze
  end
end
