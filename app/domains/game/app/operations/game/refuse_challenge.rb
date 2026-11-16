module Game
  class RefuseChallenge < Operation
    include DuelSteps

    def call(player:, token:)
      duel = step seated_duel(player, token)

      transaction do
        duel, seats = lock_duel(duel)
        step invited_friend(seats, player)
        step end_challenge("refused", DuelChallengeRefused, player, duel, seats)
        duel
      end
    end
  end
end
