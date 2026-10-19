module Catalog
  # The tiers a set gets when its season is published, by its count of
  # distinct cards: zero to five ranks before completion, counted from the
  # top (the last is always master; a smaller set drops ranks from novice
  # up), each a share of the set rounded up, then complete at all of them.
  #
  #   Catalog::TierTable.tiers(3)  # => { "complete" => 3 }
  #   Catalog::TierTable.tiers(12) # => { "expert" => 4, "master" => 8, "complete" => 12 }
  module TierTable
    RANKS = %w[novice apprentice adept expert master].freeze
    COMPLETE = "complete".freeze

    # The shares of each row, from the largest minimum size down.
    ROWS = [
      [ 200, [ Rational(1, 10), Rational(1, 4), Rational(1, 2), Rational(3, 4), Rational(9, 10) ] ],
      [ 60, [ Rational(1, 10), Rational(1, 4), Rational(1, 2), Rational(3, 4) ] ],
      [ 20, [ Rational(1, 4), Rational(1, 2), Rational(3, 4) ] ],
      [ 10, [ Rational(1, 3), Rational(2, 3) ] ],
      [ 5, [ Rational(1, 2) ] ],
      [ 0, [] ]
    ].freeze

    # The fewest cards a set needs for a tier before completion; a smaller
    # set has completion alone, whatever tiers an earlier season stored.
    SMALLEST_TIERED = ROWS.reject { |_minimum, shares| shares.empty? }.map(&:first).min

    def self.tiers(card_count)
      shares = shares(card_count)
      RANKS.last(shares.size).zip(shares).to_h { |rank, share| [ rank, (share * card_count).ceil ] }.merge(COMPLETE => card_count)
    end

    def self.shares(card_count)
      ROWS.find { |minimum, _| card_count >= minimum }.last
    end
    private_class_method :shares
  end
end
