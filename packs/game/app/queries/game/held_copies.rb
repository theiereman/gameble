module Game
  # Every card a player holds, for the trade board's card picker (CAP-11,
  # AD-6; EXPERIENCE.md, Card picker, Quantity stepper): per card-season of
  # which they hold at least one copy, the copies held, those reserved in
  # open trades, and the free ones (`quantity - reserved`, never below 0),
  # in one query. Any player may be asked about (the friend's collection);
  # nil (a visitor) holds nothing and costs no query.
  #
  #   Game::HeldCopies.call(player) # => { card_season_id => Row(quantity: 3, reserved: 1) }
  #   Game::HeldCopies.call(player)[id].free # => 2
  module HeldCopies
    Row = Data.define(:quantity, :reserved) do
      def free = [ quantity - reserved, 0 ].max
    end

    def self.call(player)
      return {} if player.nil?

      Holding.where(player_id: player.id).where(Holding.arel_table[:quantity].gt(0))
        .order(:card_season_id)
        .pluck(:card_season_id, :quantity, :reserved)
        .to_h { |card_season_id, quantity, reserved| [ card_season_id, Row.new(quantity:, reserved:) ] }
    end
  end
end
