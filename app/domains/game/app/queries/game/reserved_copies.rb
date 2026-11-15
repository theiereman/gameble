module Game
  # Why a player's reserved copies of each game are set apart: one copy per edition in a deck, then the copies on sale, then
  # what no deck nor listing explains, in a trade.
  module ReservedCopies
    Reserved = Data.define(:in_deck, :on_sale, :in_trade)

    SQL = <<~SQL.squish.freeze
      SELECT catalog_card_seasons.card_id, SUM(game_holdings.reserved) AS reserved, COUNT(decked.card_season_id) AS in_deck,
             SUM(GREATEST(LEAST(COALESCE(listed.copies, 0),
                                game_holdings.reserved - CASE WHEN decked.card_season_id IS NULL THEN 0 ELSE 1 END), 0)) AS on_sale
        FROM game_holdings
        JOIN catalog_card_seasons ON catalog_card_seasons.id = game_holdings.card_season_id
        LEFT JOIN (%{listed}) listed ON listed.card_season_id = game_holdings.card_season_id
        LEFT JOIN (%{decked}) decked ON decked.card_season_id = game_holdings.card_season_id
       WHERE game_holdings.player_id = :player_id AND game_holdings.reserved > 0
         AND catalog_card_seasons.card_id IN (:card_ids)
       GROUP BY catalog_card_seasons.card_id
    SQL

    def self.call(player, card_ids:)
      return {} if player.nil? || card_ids.empty?

      sql = Holding.sanitize_sql_array([ format(SQL, listed: listed(player).to_sql, decked: decked(player).to_sql),
        { player_id: player.id, card_ids: card_ids.uniq } ])
      Holding.connection.select_rows(sql, "Game::ReservedCopies").to_h do |card_id, reserved, in_deck, on_sale|
        in_deck = in_deck.to_i
        on_sale = on_sale.to_i
        [ card_id.to_i, Reserved.new(in_deck:, on_sale:, in_trade: [ reserved.to_i - in_deck - on_sale, 0 ].max) ]
      end
    end

    def self.listed(player)
      Market::Listing.open_now.where(seller_id: player.id).group(:card_season_id).select(:card_season_id, Arel.sql("COUNT(*) AS copies"))
    end
    private_class_method :listed

    def self.decked(player)
      DeckCard.joins(:deck).where(game_decks: { player_id: player.id }).distinct.select(:card_season_id)
    end
    private_class_method :decked
  end
end
