module Game
  module DuelsWithAbsentSeat
    def self.call(now)
      Duel.where(state: "active").where(id: DuelSeat.where(status: "seated").where(present_until: ..now).select(:duel_id)).ids
    end
  end
end
