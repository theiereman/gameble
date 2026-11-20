module Game
  class SlotBought < RubyEventStore::Event
    def self.with(player_id:, kind:, goal_id: nil) = new(data: { player_id:, kind:, goal_id: })
  end
end
