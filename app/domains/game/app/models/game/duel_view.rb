module Game
  class DuelView < Data.define(:token, :state, :move_number, :round, :caller, :mine, :theirs, :hand, :current_call, :rounds, :result,
    :deadline, :server_time)
    Side = Data.define(:role, :deck, :played, :score, :margin, :stats_left)

    def self.for(duel, seat)
      raise ArgumentError, "the seat is not at this duel" unless seat.duel_id == duel.id

      role = seat.role.to_sym
      return unstarted(duel, role) unless duel.started?

      rules = DuelRules.new(duel, duel.rounds.to_a)
      new(token: duel.token, state: duel.state.to_sym, move_number: duel.move_number, round: rules.round, caller: rules.caller,
        mine: side(rules, role), theirs: side(rules, DuelRules.other(role)), hand: rules.hand(role),
        current_call: current_call(rules, role), rounds: rules.played_rounds, result: rules.result,
        deadline: deadline(duel), server_time: Time.current)
    end

    def self.unstarted(duel, role)
      new(token: duel.token, state: duel.state.to_sym, move_number: duel.move_number, round: nil, caller: nil,
        mine: empty_side(role), theirs: empty_side(DuelRules.other(role)), hand: [], current_call: nil, rounds: [], result: nil,
        deadline: deadline(duel), server_time: Time.current)
    end

    def self.deadline(duel)
      duel.move_deadline_at if DuelClock.new(duel, []).open?
    end

    def self.empty_side(role) = Side.new(role:, deck: [], played: [], score: 0, margin: BigDecimal(0), stats_left: DuelStat::STATS)

    def self.side(rules, role)
      Side.new(role:, deck: rules.deck(role), played: rules.played(role), score: rules.scores.fetch(role),
        margin: rules.margins.fetch(role), stats_left: rules.stats_left(role))
    end

    def self.current_call(rules, role)
      locked = rules.pending
      return if locked.nil?

      card = rules.card(locked.caller.to_sym, locked.caller_card_season_id)
      return DuelRules::Call.new(card:, stat: nil, direction: nil) unless locked.caller.to_sym == role

      DuelRules::Call.new(card:, stat: locked.stat.to_sym, direction: locked.direction.to_sym)
    end
    private_class_method :deadline, :unstarted, :empty_side, :side, :current_call
  end
end
