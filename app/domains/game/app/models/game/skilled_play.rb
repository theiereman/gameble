module Game
  class SkilledPlay
    CALL_TEMPERATURE = 8.0

    def initialize(view)
      @view = view
      @payoffs = {}
    end

    def call_move
      unseen = @view.theirs.deck.reject { @view.theirs.played.include?(it.card_season_id) }
      calls = @view.hand.flat_map do |card|
        ranked = ranked_answers(card, unseen)
        chances = ranked.each_index.map { best_of_hand_chance(it, ranked.size) }
        @view.mine.stats_left.product(DuelStat::DIRECTIONS).map do |stat, direction|
          value = ranked.each_with_index.sum { |answer, index| chances[index] * payoff(card, answer, stat, direction) }
          [ DuelRules::Call.new(card:, stat:, direction:), value ]
        end
      end
      calls.max_by(&:last).first
    end

    def answer_card
      shown = @view.current_call.card
      calls = expected_calls(shown, @view.theirs.stats_left)
      @view.hand.min_by { expected_payoff(shown, it, calls) }
    end

    private

    def ranked_answers(card, unseen)
      calls = expected_calls(card, @view.mine.stats_left)
      unseen.sort_by.with_index { |answer, index| [ expected_payoff(card, answer, calls), index ] }
    end

    def best_of_hand_chance(rank, unseen_count)
      hand_size = [ DuelRules::HAND_SIZE, unseen_count ].min
      choose(unseen_count - 1 - rank, hand_size - 1).fdiv(choose(unseen_count, hand_size))
    end

    def choose(total, picked)
      return 0 if picked.negative? || picked > total

      ((total - picked + 1)..total).reduce(1, :*) / (1..picked).reduce(1, :*)
    end

    def expected_calls(card, stats)
      weights = stats.product(DuelStat::DIRECTIONS).to_h do |stat, direction|
        [ [ stat, direction ], Math.exp(DuelRules.strength(card, stat, direction).to_f / CALL_TEMPERATURE) ]
      end
      total = weights.values.sum
      weights.transform_values { it / total }
    end

    def expected_payoff(caller_card, answer_card, calls)
      calls.sum { |(stat, direction), weight| weight * payoff(caller_card, answer_card, stat, direction) }
    end

    def payoff(caller_card, answer_card, stat, direction)
      @payoffs[[ caller_card.card_season_id, answer_card.card_season_id, stat, direction ]] ||= begin
        outcome = DuelRules.outcome(caller_card, answer_card, stat, direction)
        { caller: 1, answerer: -1 }.fetch(outcome.winner, 0) * (1 + (outcome.margin.to_f / 100))
      end
    end
  end
end
