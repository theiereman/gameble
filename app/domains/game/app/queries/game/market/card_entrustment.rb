module Game
  module Market
    # What a player can entrust of one card: nil when the CONFIER button must be absent, else its free and reserved copies.
    module CardEntrustment
      State = Data.define(:free, :reserved)

      SQL = <<~SQL.squish.freeze
        SELECT COALESCE(SUM(game_holdings.quantity - game_holdings.reserved), 0), COALESCE(SUM(game_holdings.reserved), 0)
          FROM game_holdings
          JOIN catalog_card_seasons ON catalog_card_seasons.id = game_holdings.card_season_id
         WHERE game_holdings.player_id = :player_id AND game_holdings.quantity > 0
           AND catalog_card_seasons.card_id = :card_id AND catalog_card_seasons.rarity IS NOT NULL
      SQL

      def self.call(player, card_id:, state: MarketState.call)
        return if player.nil? || !(state.first_opened? && state.open?)

        sql = Holding.sanitize_sql_array([ SQL, { player_id: player.id, card_id: } ])
        free, reserved = Holding.connection.select_rows(sql, "Game::Market::CardEntrustment").first.map(&:to_i)
        State.new(free:, reserved:) if free.positive? || reserved.positive?
      end
    end
  end
end
