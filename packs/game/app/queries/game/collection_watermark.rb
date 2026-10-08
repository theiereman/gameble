module Game
  # A player's collection watermark: the latest gain they have seen
  # on their collection (Game::PlayerState#collection_seen_up_to), nil when
  # they have seen none yet. One query; nil, without one, for a visitor.
  #
  #   Game::CollectionWatermark.call(player) # => Time | nil
  module CollectionWatermark
    def self.call(player)
      return if player.nil?

      PlayerState.where(player_id: player.id).pick(:collection_seen_up_to)
    end
  end
end
