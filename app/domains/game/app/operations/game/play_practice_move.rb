module Game
  class PlayPracticeMove < Operation
    include DuelSteps

    def call(player:, token:, move_number:)
      duel = step seated_duel(player, token)
      rules = duel.rules
      step bot_to_move(duel, rules, move_number)
      step(rules.pending ? answer(player, duel, rules) : announce(player, duel, rules))
    end

    private

    def bot_to_move(duel, rules, move_number)
      mover = rules.pending ? rules.answerer : rules.caller
      duel.practice && playing(duel, move_number) && mover == PracticeBot::ROLE ? Success() : Failure(:not_your_move)
    end

    def announce(player, duel, rules)
      move = PracticeBot.call_move(rules)
      CallRound.new.call(player:, token: duel.token, move_number: duel.move_number, card: position(rules, move.card), stat: move.stat,
        direction: move.direction)
    end

    def answer(player, duel, rules)
      AnswerRound.new.call(player:, token: duel.token, move_number: duel.move_number, card: position(rules, PracticeBot.answer_card(rules)))
    end

    def position(rules, card) = rules.deck(PracticeBot::ROLE).index(card) + 1
  end
end
