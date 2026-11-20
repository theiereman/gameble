module Game
  module Capacity
    FREE = { goal: 5, custom_set: 5, deck: 3 }.freeze
    CEILING = { goal: 10, custom_set: 10, deck: 5 }.freeze

    def self.limit(player, kind)
      bought = player && CapacitySlot.where(player_id: player.id, kind: kind.to_s).pick(:bought)
      FREE.fetch(kind) + bought.to_i
    end
  end
end
