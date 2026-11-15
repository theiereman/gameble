module Game
  module PlayerDecks
    Listed = Data.define(:token, :name, :slots)

    def self.count(player)
      player ? Deck.where(player_id: player.id).count : 0
    end

    def self.room_left?(player) = count(player) < Deck::PER_PLAYER

    def self.listing(player)
      return [] if player.nil?

      decks = Deck.where(player_id: player.id).order(:created_at, :id).pluck(:id, :token, :name)
      slots = DeckCard.where(deck_id: decks.map(&:first)).order(:slot).pluck(:deck_id, :slot, :card_season_id)
        .group_by(&:first).transform_values { |rows| rows.to_h { |_, slot, card_season_id| [ slot, card_season_id ] } }
      decks.map { |id, token, name| Listed.new(token:, name:, slots: slots.fetch(id, {})) }
    end
  end
end
