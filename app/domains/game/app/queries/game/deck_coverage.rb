module Game
  class DeckCoverage
    GAP_BELOW = 90
    GOOD_FROM = 75
    MANY_AT = 3
    DIRECTIONS = %w[high low].freeze
    CALLS = DuelStat::STATS.flat_map { |stat| DIRECTIONS.map { [ stat, it ] } }.freeze

    Call = Data.define(:stat, :direction, :best, :good) do
      def key = DeckCoverage.key(stat, direction)

      def gap? = best.nil? || best < GAP_BELOW

      def many? = good >= MANY_AT

      def shown = best&.round&.clamp(0, 99)
    end

    def self.key(stat, direction) = "#{stat}-#{direction}"

    def self.percentile_in(profile, stat, direction)
      percentile = profile&.stat(stat)&.percentile
      return if percentile.nil?

      direction == "high" ? percentile : 100 - percentile
    end

    def initialize(deck)
      @deck = deck
    end

    def calls
      @calls ||= begin
        deck_profiles = DuelProfiles.call(in_deck)
        CALLS.map do |stat, direction|
          strengths = in_deck.filter_map { self.class.percentile_in(deck_profiles[it], stat, direction) }
          Call.new(stat:, direction:, best: strengths.max, good: strengths.count { it >= GOOD_FROM })
        end
      end
    end

    private
      def in_deck = @in_deck ||= DeckSlots.call(@deck).values
  end
end
