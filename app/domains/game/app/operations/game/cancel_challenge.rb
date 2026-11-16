module Game
  class CancelChallenge < Operation
    include DuelSteps

    def call(player:, token:)
      duel = step seated_duel(player, token)

      transaction do
        duel, seats = lock_duel(duel)
        step challenger(seats, player)
        step end_challenge("cancelled", DuelChallengeCancelled, player, duel, seats)
        duel
      end
    end
  end
end
