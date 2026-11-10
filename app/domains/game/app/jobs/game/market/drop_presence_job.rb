module Game
  module Market
    class DropPresenceJob < ActiveJob::Base
      queue_as :default

      def perform
        drop(RemovedPresence.sellers, WithdrawListing, WithdrawListing::NOT_WITHDRAWABLE)
        drop(RemovedPresence.leaders(now: Time.current), VoidLead, VoidLead::LEAD_NOT_VOIDABLE)
        forfeit(RemovedPresence.wallets)
      end

      private

      def forfeit(player_ids)
        Accounts::Player.where(id: player_ids).each do |player|
          result = ForfeitBalance.new.call(player:)
          result.value! unless ForfeitBalance::SKIPPED.include?(result)
        rescue StandardError => error
          Rails.error.report(error, context: { player_id: player.id })
        end
      end

      def drop(listings, operation, skipped)
        sellers = Accounts::Player.where(id: listings.map(&:last)).index_by(&:id)
        listings.each do |listing_id, seller_id|
          result = operation.new.call(player: sellers[seller_id], listing_id:)
          result.value! unless result == skipped
        rescue StandardError => error
          Rails.error.report(error, context: { listing_id: })
        end
      end
    end
  end
end
