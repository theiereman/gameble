module Game
  class PlayAutomaticMove < Operation
    include DuelSteps

    def call(player:, token:, move_number:)
      duel = step seated_duel(player, token)

      transaction do
        duel, seats = lock_duel(duel)
        rules = duel.rules
        step due("active", duel, seats, move_number, rules)
        step(rules.pending ? play_answer(player, duel, rules) : play_call(player, duel, rules))
      end
    end

    private

    def play_call(player, duel, rules)
      move = rules.automatic_call
      CallRound.new.call(player:, token: duel.token, move_number: duel.move_number, card: rules.deck(rules.caller).index(move.card) + 1,
        stat: move.stat, direction: move.direction, automatic: true)
    end

    def play_answer(player, duel, rules)
      AnswerRound.new.call(player:, token: duel.token, move_number: duel.move_number,
        card: rules.deck(rules.answerer).index(rules.automatic_answer) + 1, automatic: true)
    end
  end
end
