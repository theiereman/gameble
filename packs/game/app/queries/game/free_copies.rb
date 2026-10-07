module Game
  # The copies a player may still place in a trade (AD-6; EXPERIENCE.md,
  # Quantity stepper): per card-season asked about, the copies held minus
  # those reserved in open trades, only where that is above zero. Empty for
  # a visitor.
  #
  #   Game::FreeCopies.call(player, [ card_season_id, … ]) # => { card_season_id => free }
  module FreeCopies
    def self.call(player, card_season_ids)
      return {} if player.nil? || card_season_ids.empty?

      holdings = Holding.arel_table
      Holding.where(player_id: player.id, card_season_id: card_season_ids.uniq)
        .where(holdings[:quantity].gt(holdings[:reserved]))
        .pluck(:card_season_id, Arel.sql("quantity - reserved"))
        .to_h
    end
  end
end
