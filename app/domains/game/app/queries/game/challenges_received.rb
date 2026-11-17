module Game
  module ChallengesReceived
    Challenge = Data.define(:duel_id, :challenger_id)

    def self.call(player_id)
      DuelSeat.where(player_id:, status: "invited").includes(duel: :seats).select { it.duel.state == "challenged" }
        .map { |seat| Challenge.new(duel_id: seat.duel_id, challenger_id: seat.duel.seats.find { it.role == "challenger" }.player_id) }
    end
  end
end
