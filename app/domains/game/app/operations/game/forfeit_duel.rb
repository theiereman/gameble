module Game
  class ForfeitDuel < Operation
    include DuelSteps

    def call(player:, token:)
      step require_player(player)
      duel = step seated_duel(player, token)

      transaction do
        duel, seats = lock_duel(duel)
        role = step role_of(seats, player)
        step active(duel)
        duel.update!(state: "finished", result: DuelRules.other(role).to_s, forfeited_by: role.to_s, ended_at: Time.current,
          move_number: next_move(duel), move_deadline_at: nil)
        step close_seats(DuelFinished, player, duel, seats)
        duel
      end
    end

    private

    def active(duel) = duel.state == "active" ? Success() : Failure(:not_your_move)
  end
end
