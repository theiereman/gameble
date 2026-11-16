module Game
  module HeldSeats
    Held = Data.define(:seated, :invited)

    def self.call(player)
      return Held.new(seated: nil, invited: nil) if player.nil?

      seats = DuelSeat.includes(duel: :seats).where(player_id: player.id, status: %w[seated invited]).index_by(&:status)
      Held.new(seated: seats["seated"], invited: seats["invited"])
    end
  end
end
