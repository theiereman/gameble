module Catalog
  module TierTable
    RANKS = %w[novice apprentice adept expert master].freeze
    COMPLETE = "complete".freeze

    ROWS = [
      [ 200, [ Rational(1, 10), Rational(1, 4), Rational(1, 2), Rational(3, 4), Rational(9, 10) ] ],
      [ 60, [ Rational(1, 10), Rational(1, 4), Rational(1, 2), Rational(3, 4) ] ],
      [ 20, [ Rational(1, 4), Rational(1, 2), Rational(3, 4) ] ],
      [ 10, [ Rational(1, 3), Rational(2, 3) ] ],
      [ 5, [ Rational(1, 2) ] ],
      [ 0, [] ]
    ].freeze

    SMALLEST_TIERED = ROWS.reject { |_minimum, shares| shares.empty? }.map(&:first).min

    def self.tiers(card_count)
      shares = shares(card_count)
      RANKS.last(shares.size).zip(shares).to_h { |rank, share| [ rank, (share * card_count).ceil ] }.merge(COMPLETE => card_count)
    end

    def self.tiered?(card_count)
      card_count >= SMALLEST_TIERED
    end

    def self.shares(card_count)
      ROWS.find { |minimum, _| card_count >= minimum }.last
    end
    private_class_method :shares
  end
end
