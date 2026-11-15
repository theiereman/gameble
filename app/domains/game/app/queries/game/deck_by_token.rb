module Game
  module DeckByToken
    def self.call(token)
      return nil unless token.is_a?(String) && token.present?

      Deck.find_by(token:)
    end
  end
end
