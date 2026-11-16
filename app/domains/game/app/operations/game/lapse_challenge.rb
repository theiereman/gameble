module Game
  class LapseChallenge < Operation
    include DuelSteps

    def call(player:, token:, move_number:)
      duel = step seated_duel(player, token)

      transaction do
        duel, seats = lock_duel(duel)
        step due("challenged", duel, seats, move_number)
        step lapse(player, duel, seats)
        duel
      end
    end
  end
end
