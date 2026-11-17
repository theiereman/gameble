module Game
  class ReleaseDuelSeats < Operation
    def call(player:)
      player = step require_account(player)

      transaction do
        lapse_received_challenge(player)
        DuelSeat.where(player_id: player.id, status: "left").update_all(player_id: nil, updated_at: Time.current)
        player
      end
    end

    private

    def lapse_received_challenge(player)
      seat = DuelSeat.find_by(player_id: player.id, status: "invited")
      return unless seat

      duel = Duel.lock.find(seat.duel_id)
      return unless duel.state == "challenged"

      DuelSeat.where(duel_id: duel.id).order(:id).lock.each { it.update!(status: "left") }
      duel.update!(state: "lapsed", ended_at: Time.current, move_number: duel.move_number + 1)
    end
  end
end
