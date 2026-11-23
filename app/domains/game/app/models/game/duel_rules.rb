module Game
  class DuelRules
    VERSION = 1
    ROLES = %i[challenger opponent].freeze
    ROUNDS = 10
    HAND_SIZE = 3
    FIRST_CALLER_ROUNDS = [ 1, 3, 5, 7, 10 ].freeze

    Outcome = Data.define(:winner, :decided_on_value, :margin)
    Call = Data.define(:card, :stat, :direction)
    Played = Data.define(:number, :caller, :caller_card, :answer_card, :stat, :direction, :winner, :decided_on_value, :margin,
      :caller_automatic, :answer_automatic)

    NO_POINT = Outcome.new(winner: nil, decided_on_value: false, margin: BigDecimal(0))

    def self.other(role) = role.to_sym == :challenger ? :opponent : :challenger

    def self.caller(round, first_caller)
      FIRST_CALLER_ROUNDS.include?(round) ? first_caller.to_sym : other(first_caller)
    end

    def self.strength(card, stat, direction)
      percentile = card.stat(stat).percentile
      return -1 if percentile.nil?

      { high: percentile, low: 100 - percentile }.fetch(direction)
    end

    def self.outcome(caller_card, answer_card, stat, direction)
      calling = strength(caller_card, stat, direction)
      answering = strength(answer_card, stat, direction)
      return by_value(caller_card, answer_card, stat, direction) if calling == answering

      losing, winning = [ calling, answering ].sort
      Outcome.new(winner: calling > answering ? :caller : :answerer, decided_on_value: false, margin: winning - [ losing, 0 ].max)
    end

    def self.by_value(caller_card, answer_card, stat, direction)
      calling_valued, answering_valued = [ caller_card, answer_card ].map { !it.stat(stat).value.nil? }
      return Outcome.new(winner: calling_valued ? :caller : :answerer, decided_on_value: true, margin: BigDecimal(0)) if calling_valued ^ answering_valued

      order = (exact_value(caller_card, stat) <=> exact_value(answer_card, stat)).to_i
      order = -order if (stat == :discovery) ^ (direction == :low)
      return NO_POINT if order.zero?

      Outcome.new(winner: order.positive? ? :caller : :answerer, decided_on_value: true, margin: BigDecimal(0))
    end
    private_class_method :by_value

    def self.exact_value(card, stat)
      value = card.stat(stat).value
      stat == :rating ? [ value, card.stat(:popularity).value.to_i ] : value
    end
    private_class_method :exact_value

    def initialize(duel, rounds)
      @duel = duel
      @rounds = rounds.sort_by(&:number)
      @decks = {}
    end

    def revealed = @rounds.select(&:answered_at)

    def pending = @rounds.find { it.answered_at.nil? }

    def round = [ revealed.size + 1, ROUNDS ].min

    def finished? = revealed.size == ROUNDS

    def caller = self.class.caller(round, @duel.first_caller)

    def answerer = self.class.other(caller)

    def deck(role) = @decks[role] ||= @duel.cards(role)

    def card(role, card_season_id) = deck(role).find { it.card_season_id == card_season_id }

    def played(role)
      @rounds.filter_map { it.caller.to_sym == role ? it.caller_card_season_id : it.answer_card_season_id }
    end

    def hand(role)
      held = @duel.draw_order(role).first(round + HAND_SIZE - 1) - played(role)
      deck(role).select { held.include?(it.card_season_id) }
    end

    def stats_left(role)
      DuelStat::STATS - revealed.select { it.caller.to_sym == role }.map { it.stat.to_sym }
    end

    def played_rounds
      revealed.map do |row|
        role = row.caller.to_sym
        stat = row.stat.to_sym
        direction = row.direction.to_sym
        caller_card = card(role, row.caller_card_season_id)
        answer_card = card(self.class.other(role), row.answer_card_season_id)
        outcome = self.class.outcome(caller_card, answer_card, stat, direction)
        Played.new(number: row.number, caller: role, caller_card:, answer_card:, stat:, direction:,
          winner: { caller: role, answerer: self.class.other(role) }[outcome.winner], decided_on_value: outcome.decided_on_value,
          margin: outcome.margin, caller_automatic: row.caller_automatic, answer_automatic: row.answer_automatic)
      end
    end

    def scores
      won = played_rounds.map(&:winner)
      ROLES.index_with { |role| won.count(role) }
    end

    def margins
      played = played_rounds
      ROLES.index_with { |role| played.select { it.winner == role }.sum(BigDecimal(0), &:margin) }
    end

    def result
      return unless finished?

      [ scores, margins ].each do |totals|
        return totals.max_by(&:last).first if totals[:challenger] != totals[:opponent]
      end
      :draw
    end

    def automatic_call
      role = caller
      calls = hand(role).product(stats_left(role)).map { |card, stat| Call.new(card:, stat:, direction: side(card, stat)) }
      calls.max_by { [ *preference(it.card, it.stat, it.direction), -DuelStat::STATS.index(it.stat), -deck(role).index(it.card) ] }
    end

    def automatic_answer
      shown = card(caller, pending.caller_card_season_id)
      stat = stats_left(caller).max_by { [ *preference(shown, it, side(shown, it)), -DuelStat::STATS.index(it) ] }
      direction = side(shown, stat)
      hand(answerer).max_by { [ *preference(it, stat, direction), -deck(answerer).index(it) ] }
    end

    private

    def side(card, stat) = (card.stat(stat).percentile || 50) >= 50 ? :high : :low

    def preference(card, stat, direction) = [ self.class.strength(card, stat, direction), card.stat(stat).median_distance || -1 ]
  end
end
