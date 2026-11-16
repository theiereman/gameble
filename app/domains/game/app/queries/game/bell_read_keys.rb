module Game
  # The keys of the bell lines a player has read, on whichever device.
  module BellReadKeys
    def self.call(player)
      BellRead.where(player_id: player.id).pluck(:key).to_set
    end
  end
end
