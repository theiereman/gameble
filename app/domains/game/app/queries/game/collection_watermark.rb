module Game
  module CollectionWatermark
    def self.call(player)
      return if player.nil?

      PlayerState.where(player_id: player.id).pick(:collection_seen_up_to)
    end
  end
end
