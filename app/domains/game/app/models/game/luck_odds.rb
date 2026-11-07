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

    def self.reward_with_epic_guarantee
      below = DrawOdds::REWARD.select { |tier, _| tier < RewardDraw::MIN_TIER }
      none_epic = (below.values.sum.fdiv(DrawOdds::TOTAL))**Pack::SIZE
      drawn = card(DrawOdds::REWARD) * Pack::SIZE
      all_below = card(below) * Pack::SIZE
      one_redrawn = card(below) * (Pack::SIZE - 1) + card(DrawOdds::EPIC_OR_BETTER)

      mean = drawn.points + none_epic * (one_redrawn.points - all_below.points)
      square = drawn.second_moment + none_epic * (one_redrawn.second_moment - all_below.second_moment)
      Expectation.new(points: mean, variance: square - mean**2)
    end

    private_class_method :card, :reward_with_epic_guarantee

    EXPECTATIONS = {
      "regular" => card(DrawOdds::REGULAR) * Pack::SIZE,
      "bonus" => card(DrawOdds::BONUS) * Pack::BONUS_SIZE,
      "reward" => reward_with_epic_guarantee
    }.freeze
  end
end
