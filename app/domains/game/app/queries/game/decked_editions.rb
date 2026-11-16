module Game
  module DeckedEditions
    def self.call(player, except: nil)
      return Set.new if player.nil?

      cards = DeckCard.of_player(player.id)
      cards = cards.where.not(deck_id: except.id) if except
      cards.distinct.pluck(:card_season_id).to_set
    end
  end
end
