module Game
  module DuelInProgress
    def self.call(player)
      seat = HeldSeats.call(player).seated
      seat if seat&.duel&.state == "active"
    end

    def self.count(player) = call(player) ? 1 : 0
  end
end
