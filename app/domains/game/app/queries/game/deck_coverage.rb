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
      percentile = profile&.stats&.find { it.name == stat }&.percentile
      return if percentile.nil?

      direction == "high" ? percentile : 100 - percentile
    end

    def initialize(player, deck, card_season_ids: nil)
      @player = player
      @deck = deck
      @card_season_ids = card_season_ids
    end

    def calls
      @calls ||= begin
        deck_profiles = DuelProfiles.call(in_deck)
        CALLS.map { |stat, direction| Call.new(stat:, direction:, best: best_in(in_deck, deck_profiles, stat, direction)) }
      end
    end

    def fill(room:)
      picks = []
      pool = candidates
      CALLS.each do |stat, direction|
        break if picks.size >= room
        next unless gap_in?(in_deck + picks, stat, direction)

        pick = strongest(pool) { self.class.percentile_in(profiles[it], stat, direction) }
        pool = take(picks, pool, pick) if pick
      end
      while picks.size < room && (pick = strongest(pool) { trump_strength(profiles[it]) })
        pool = take(picks, pool, pick)
      end
      picks
    end

    private
      def in_deck = @in_deck ||= @card_season_ids || DeckSlots.call(@deck).values

      def held = @held ||= HeldCopies.call(@player)

      def profiles = @profiles ||= DuelProfiles.call(in_deck | held.keys)

      def games = @games ||= Catalog::CardSeason.where(id: in_deck | held.keys).pluck(:id, :card_id).to_h

      def candidates
        decked_elsewhere = DeckedEditions.call(@player, except: @deck)
        deck_games = in_deck.map { games[it] }.to_set
        held.filter_map do |card_season_id, row|
          next if in_deck.include?(card_season_id) || deck_games.include?(games[card_season_id])
          next unless profiles[card_season_id]&.ranked?

          card_season_id if row.free >= 1 || decked_elsewhere.include?(card_season_id)
        end
      end

      def best_in(card_season_ids, by_card_season, stat, direction)
        card_season_ids.filter_map { self.class.percentile_in(by_card_season[it], stat, direction) }.max
      end

      def gap_in?(card_season_ids, stat, direction)
        Call.new(stat:, direction:, best: best_in(card_season_ids, profiles, stat, direction)).gap?
      end

      def strongest(pool)
        scored = pool.filter_map { |card_season_id| (value = yield(card_season_id)) && [ value, card_season_id ] }
        scored.max_by { |value, card_season_id| [ value, -card_season_id ] }&.last
      end

      def take(picks, pool, pick)
        picks << pick
        pool.reject { games[it] == games[pick] }
      end

      def trump_strength(profile)
        percentile = profile&.trump&.percentile
        [ percentile, 100 - percentile ].max unless percentile.nil?
      end
  end
end
