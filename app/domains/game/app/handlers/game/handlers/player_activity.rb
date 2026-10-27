module Game
  module Handlers
    module PlayerActivity
      EVENTS = {
        Game::PackOpened => [ :opening_pack, :player_id ],
        Game::DailyBonusCollected => [ :collecting_daily, :player_id ],
        Game::TradeProposed => [ :trading, :proposer_id ],
        Game::TradeCancelled => [ :trading, :proposer_id ],
        Game::TradeDeclined => [ :trading, :recipient_id ],
        Game::TradeCountered => [ :trading, :proposer_id ],
        Game::TradeAccepted => [ :trading, :recipient_id ],
        Game::InvitationSent => [ :making_friends, :sender_id ],
        Game::InvitationAccepted => [ :making_friends, :recipient_id ]
      }.freeze

      def self.call(event)
        activity, actor = EVENTS.fetch(event.class)
        at = event.metadata[:timestamp] || Time.current
        PlayerState.upsert(
          { player_id: event.data.fetch(actor), last_activity: activity.to_s, last_activity_at: at, created_at: at, updated_at: at },
          unique_by: :player_id, record_timestamps: false,
          on_duplicate: Arel.sql("last_activity = excluded.last_activity, last_activity_at = excluded.last_activity_at, " \
            "updated_at = excluded.updated_at")
        )
      end
    end
  end
end
