module Game
  module DeckArchetypes
    NAMES = %w[coverage popularity rating release discovery circulation two_stats trumps random].freeze
    OTHER = "other".freeze
    SIZE = Deck::SLOTS.size
    STRONG = DeckCoverage::GAP_BELOW
    STAT_DECK_STRONG = 10
    PAIR_STAT_STRONG = 5
    TRUMP_FLOOR = 98
    CALLS = DuelStat::STATS.product(DuelStat::DIRECTIONS).freeze

    def self.build(name, pool, random: Random)
      shuffled = pool.shuffle(random:)
      case name
      when "coverage" then coverage(shuffled)
      when "two_stats" then by_stats(shuffled, DuelStat::STATS.sample(2, random:), SIZE / 2)
      when "trumps" then extended([], ranked(shuffled) { trump(it) }, SIZE)
      when "random" then extended([], shuffled, SIZE)
      else by_stats(shuffled, [ name.to_sym ], SIZE)
      end
    end

    def self.classify(cards)
      strong = DuelStat::STATS.index_with { |stat| cards.count { extremity(it, stat) >= STRONG } }
      single = DuelStat::STATS.find { strong[it] >= STAT_DECK_STRONG }
      if CALLS.all? { |stat, direction| cards.any? { DuelRules.strength(it, stat, direction) >= STRONG } } then "coverage"
      elsif single then single.to_s
      elsif DuelStat::STATS.combination(2).any? { two_stat?(cards, strong, it) } then "two_stats"
      elsif cards.any? && cards.all? { trump(it) >= TRUMP_FLOOR } then "trumps"
      else OTHER
      end
    end

    def self.coverage(pool)
      deck = CALLS.reduce([]) do |cards, (stat, direction)|
        next cards if cards.any? { DuelRules.strength(it, stat, direction) >= STRONG }

        left = fresh(cards, pool)
        choice = left.find { DuelRules.strength(it, stat, direction) >= STRONG } || left.max_by { DuelRules.strength(it, stat, direction) }
        choice ? cards + [ choice ] : cards
      end
      extended(deck, ranked(pool) { trump(it) }, SIZE - deck.size)
    end

    def self.by_stats(pool, stats, each)
      stats.reduce([]) { |deck, stat| extended(deck, ranked(pool) { extremity(it, stat) }, each) }
    end

    def self.two_stat?(cards, strong, pair)
      pair.all? { strong[it] >= PAIR_STAT_STRONG } &&
        cards.count { |card| pair.any? { extremity(card, it) >= STRONG } } >= STAT_DECK_STRONG
    end

    def self.ranked(pool, &score) = pool.sort_by.with_index { |card, index| [ -score.(card), index ] }

    def self.extended(deck, candidates, count) = deck + fresh(deck, candidates).uniq(&:card_id).first(count)

    def self.fresh(deck, candidates) = candidates.reject { |card| deck.any? { it.card_id == card.card_id } }

    def self.extremity(card, stat) = DuelStat::DIRECTIONS.map { DuelRules.strength(card, stat, it) }.max

    def self.trump(card) = CALLS.map { |stat, direction| DuelRules.strength(card, stat, direction) }.max

    private_class_method :coverage, :by_stats, :two_stat?, :ranked, :extended, :fresh, :extremity, :trump
  end
end
