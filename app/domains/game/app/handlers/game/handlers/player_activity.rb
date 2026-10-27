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
        RecordPlayerActivity.new.call(player_id: event.data.fetch(actor), activity:, at:).value!
      end
    end
  end
end
