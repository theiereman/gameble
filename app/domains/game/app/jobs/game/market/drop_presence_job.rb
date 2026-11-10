module Game
  module Market
    class DropPresenceJob < ActiveJob::Base
      queue_as :default

      def perform
        drop(RemovedPresence.sellers, WithdrawListing, WithdrawListing::NOT_WITHDRAWABLE)
        drop(RemovedPresence.leaders(now: Time.current), VoidLead, VoidLead::LEAD_NOT_VOIDABLE)
      end

      private

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
