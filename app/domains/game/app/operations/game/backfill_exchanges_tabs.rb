module Game
  class BackfillExchangesTabs < ApplicationOperation
    RECENT = 30.days

    def call(now: Time.current)
      transaction do
        player_ids = recent_friend_traders_without_a_tab(now)
        keep_friends(player_ids, now)
        step publish(ExchangesTabsBackfilled.new, stream_name: ExchangesTabsBackfilled::STREAM)
        player_ids.size
      end
    end

    private

    def recent_friend_traders_without_a_tab(now)
      trades = Trade.where(status: "accepted", closed_at: (now - RECENT)..now)
      players = Accounts::Player.where(deleted_at: nil)
      players.where(id: trades.select(:proposer_id)).or(players.where(id: trades.select(:recipient_id)))
        .where.not(id: PlayerState.where.not(exchanges_tab: nil).select(:player_id))
        .pluck(:id)
    end

    def keep_friends(player_ids, now)
      return if player_ids.empty?

      markers = PlayerState.markers_at_published_season
      rows = player_ids.map { { player_id: it, exchanges_tab: "friends", created_at: now, updated_at: now, **markers } }
      PlayerState.upsert_all(rows, unique_by: :player_id, record_timestamps: false,
        on_duplicate: Arel.sql("exchanges_tab = COALESCE(game_player_states.exchanges_tab, excluded.exchanges_tab), updated_at = excluded.updated_at"))
    end
  end
end
