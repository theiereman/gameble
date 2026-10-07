module Game
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
