module Game
  module Market
    module BestVisibleOrder
      VISIBLE_AFTER = 1.hour

      def self.call(card_id, viewer:, now: Time.current)
        Order.open_at(now).where(card_id:).where(created_at: ..(now - VISIBLE_AFTER))
          .where.not(player_id: [ viewer.id, *TiedAccounts.call(viewer) ])
          .where.not(player_id: Accounts::Player.removed.select(:id))
          .maximum(:price)
      end
    end
  end
end
