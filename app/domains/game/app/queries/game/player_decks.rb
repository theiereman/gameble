module Game
  module PlayerDecks
    def self.count(player)
      player ? Deck.where(player_id: player.id).count : 0
    end

    def self.room_left?(player) = count(player) < Deck::PER_PLAYER
  end
end
