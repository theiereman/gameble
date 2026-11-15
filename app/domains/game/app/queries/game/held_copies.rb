module Game
  module HeldCopies
    # `offerable`: what a friend may ask for, the copy a deck blocks left out.
    Row = Data.define(:quantity, :reserved, :in_deck) do
      def initialize(quantity:, reserved:, in_deck: false) = super

      def free = [ quantity - reserved, 0 ].max

      def offerable = [ quantity - (in_deck ? 1 : 0), 0 ].max
    end

    IN_DECK = <<~SQL.squish.freeze
      EXISTS (SELECT 1 FROM game_deck_cards JOIN game_decks ON game_decks.id = game_deck_cards.deck_id
               WHERE game_decks.player_id = game_holdings.player_id AND game_deck_cards.card_season_id = game_holdings.card_season_id)
    SQL

    def self.call(player)
      return {} if player.nil?

      Holding.where(player_id: player.id).where(Holding.arel_table[:quantity].gt(0))
        .order(:card_season_id)
        .pluck(:card_season_id, :quantity, :reserved, Arel.sql(IN_DECK))
        .to_h { |card_season_id, quantity, reserved, in_deck| [ card_season_id, Row.new(quantity:, reserved:, in_deck:) ] }
    end
  end
end
