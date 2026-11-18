module Game
  class DeckCoverage
    GAP_BELOW = 90
    DIRECTIONS = %w[high low].freeze
    CALLS = DuelStat::STATS.flat_map { |stat| DIRECTIONS.map { [ stat, it ] } }.freeze

    Call = Data.define(:stat, :direction, :best) do
      def key = DeckCoverage.key(stat, direction)

      def gap? = best.nil? || best < GAP_BELOW

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
        CALLS.map { |stat, direction| Call.new(stat:, direction:, best: best_in(in_deck, deck_profiles, stat, direction)) }
      end
    end

    private
      def in_deck = @in_deck ||= DeckSlots.call(@deck).values

      def best_in(card_season_ids, by_card_season, stat, direction)
        card_season_ids.filter_map { self.class.percentile_in(by_card_season[it], stat, direction) }.max
      end
  end
end
