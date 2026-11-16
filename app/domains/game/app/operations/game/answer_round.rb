module Game
  class AnswerRound < Operation
    include DuelSteps

    def call(player:, token:, move_number:, card:, automatic: false)
      step require_player(player) unless automatic
      move_number = step whole_number(move_number)
      position = step whole_number(card)
      duel = step seated_duel(player, token)

      transaction do
        duel, seats = lock_duel(duel)
        role = step role_of(seats, player)
        rules = DuelRules.new(duel, duel.rounds.to_a)
        step answering(duel, rules, role, move_number)
        card = step card_in_hand(rules, role, position)
        round = answer(rules, card, automatic)
        step settle(player, duel, seats, DuelRules.new(duel, duel.rounds.to_a), round)
        duel
      end
    end

    private

    def answering(duel, rules, role, move_number)
      playing(duel, move_number) && rules.pending && rules.answerer == role ? Success() : Failure(:not_your_move)
    end

    def answer(rules, card, automatic)
      round = rules.pending
      caller_card = rules.card(rules.caller, round.caller_card_season_id)
      outcome = DuelRules.outcome(caller_card, card, round.stat.to_sym, round.direction.to_sym)
      round.update!(answer_card_season_id: card.card_season_id, answer_value: snapshot_value(card, round.stat), answered_at: Time.current,
        answer_automatic: automatic, winner: { caller: rules.caller, answerer: rules.answerer }[outcome.winner]&.to_s, decided_on_value: outcome.decided_on_value)
      round
    end

    def settle(player, duel, seats, rules, round)
      scores = rules.scores
      margins = rules.margins
      totals = { challenger_score: scores[:challenger], opponent_score: scores[:opponent], challenger_margin: margins[:challenger],
        opponent_margin: margins[:opponent], move_number: next_move(duel) }
      return finish(player, duel, seats, rules, totals) if rules.finished?

      duel.update!(totals.merge(move_deadline_at: schedule(duel, totals[:move_number], DuelClock::CALL)))
      round_published(DuelRoundAnswered, player, duel, round.number)
    end

    def finish(player, duel, seats, rules, totals)
      duel.update!(**totals, state: "finished", result: rules.result.to_s, ended_at: Time.current)
      leave(seats)
      duel_published(DuelFinished, player, duel, seats)
    end
  end
end
