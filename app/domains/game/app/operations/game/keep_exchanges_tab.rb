module Game
  class KeepExchangesTab < Operation
    def call(player:, tab:)
      player = step require_player(player)
      tab = step known_tab(tab)

      transaction do
        next tab if ExchangesTab.call(player) == tab

        store(player, tab)
        step publish(ExchangesTabKept.new(data: { player_id: player.id }), stream_name: stream_name(player.id))
        tab
      end
    end

    private

    def known_tab(tab)
      ExchangesTab::TABS.include?(tab) ? Success(tab) : Failure(:unknown_tab)
    end

    def store(player, tab)
      now = Time.current
      PlayerState.upsert({ player_id: player.id, exchanges_tab: tab, created_at: now, updated_at: now, **PlayerState.markers_at_published_season },
        unique_by: :player_id, record_timestamps: false,
        on_duplicate: Arel.sql("exchanges_tab = excluded.exchanges_tab, updated_at = excluded.updated_at"))
    end
  end
end
