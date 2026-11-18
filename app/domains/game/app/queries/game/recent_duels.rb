module Game
  module RecentDuels
    LIMIT = 10

    Result = Data.define(:token, :outcome, :score, :other_score, :opponent_id)

    def self.call(player, limit: LIMIT)
      return [] if player.nil?

      seats = DuelSeat.where(player_id: player.id).joins(:duel).merge(Duel.where(state: "finished", practice: false))
        .preload(duel: :seats).order("game_duels.ended_at DESC, game_duels.id DESC").limit(limit)
      seats.map { result_of(it) }
    end

    def self.result_of(seat)
      duel = seat.duel
      other = duel.seats.find { it.role != seat.role }
      Result.new(token: duel.token, outcome: outcome_of(duel.result, seat.role), score: duel.public_send(:"#{seat.role}_score"),
        other_score: duel.public_send(:"#{other.role}_score"), opponent_id: other.player_id)
    end

    def self.outcome_of(result, role)
      return :draw if result == "draw"

      result == role ? :win : :loss
    end

    private_class_method :result_of, :outcome_of
  end
end
