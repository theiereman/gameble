module Game
  # The collection's slots a player holds (CAP-6, AD-26): for each
  # card-season asked about of which they hold at least one copy, the copies,
  # whether it is new and when it was last gained. New: copies gained
  # (`last_gained_at`) after the player's watermark
  # (`collection_seen_up_to`), any gain while the watermark is NULL; a
  # holding gained before AD-26 (NULL `last_gained_at`) is never new. One
  # query, the player's state joined; nil (a visitor) holds nothing and
  # costs no query.
  #
  #   Game::CollectionSlots.call(player, [ card_season_id, … ])
  #   # => { card_season_id => Slot(copies: 3, new: true, gained_at: Time) }
  module CollectionSlots
    Slot = Data.define(:copies, :new, :gained_at)

    NEW = <<~SQL.squish.freeze
      (game_holdings.last_gained_at IS NOT NULL
        AND (game_player_states.collection_seen_up_to IS NULL
             OR game_holdings.last_gained_at > game_player_states.collection_seen_up_to))
    SQL

    def self.call(player, card_season_ids)
      return {} if player.nil? || card_season_ids.empty?

      holdings = Holding.arel_table
      Holding.where(player_id: player.id, card_season_id: card_season_ids.uniq)
        .where(holdings[:quantity].gt(0))
        .joins("LEFT JOIN game_player_states ON game_player_states.player_id = game_holdings.player_id")
        .pluck(:card_season_id, :quantity, :last_gained_at, Arel.sql(NEW))
        .to_h { |id, copies, gained_at, fresh| [ id, Slot.new(copies:, new: fresh, gained_at:) ] }
    end
  end
end
