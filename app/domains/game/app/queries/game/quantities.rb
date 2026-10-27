module Game
  module Quantities
    def self.call(player, card_season_ids)
      return {} if player.nil? || card_season_ids.empty?

      holdings = Holding.arel_table
      Holding.where(player_id: player.id, card_season_id: card_season_ids.uniq)
        .where(holdings[:quantity].gt(0))
        .pluck(:card_season_id, :quantity)
        .to_h
    end
  end
end
