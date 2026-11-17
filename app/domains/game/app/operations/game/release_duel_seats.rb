module Game
  class ReleaseDuelSeats < Operation
    include DuelSteps

    def call(player:)
      player = step require_account(player)

      transaction do
        step lapse_received_challenge(player)
        DuelSeat.where(player_id: player.id, status: "left").update_all(player_id: nil, updated_at: Time.current)
        player
      end
    end

    private

    def lapse_received_challenge(player)
      seat = DuelSeat.find_by(player_id: player.id, status: "invited")
      return Success() unless seat

      duel = Duel.lock.find(seat.duel_id)
      return Success() unless duel.state == "challenged"

      seats = DuelSeat.where(duel_id: duel.id).order(:id).lock.index_by { it.role.to_sym }
      lapse(player, duel, seats)
    end
  end
end
