module Game
  module LastUsedDeck
    def self.call(player)
      DuelSeat.where(player_id: player.id).where.not(deck_token: nil).order(:id).last&.deck_token
    end
  end
end
