module Game
  # How many copies a player holds of each card-season asked about (CAP-6),
  # in one query: only those of which they hold at least one. Any player may
  # be asked about, not only the one signed in; nil (a visitor) holds
  # nothing and costs no query.
  #
  #   Game::Quantities.call(player, [ card_season_id, … ]) # => { card_season_id => quantity }
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
