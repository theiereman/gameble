module Game
  class CloseDueAuctionsJob < ActiveJob::Base
    queue_as :default

    BATCH_SIZE = 100

    def perform
      Market::Listing.due(Time.current).in_batches(of: BATCH_SIZE) do |batch|
        listings = batch.pluck(:id, :seller_id)
        sellers = Accounts::Player.where(id: listings.map(&:last)).index_by(&:id)
        listings.each do |listing_id, seller_id|
          result = Market::CloseAuction.new.call(player: sellers[seller_id], listing_id:)
          result.value! unless result == Market::CloseAuction::CLOSED_MEANWHILE
        rescue StandardError => error
          Rails.error.report(error, context: { listing_id: })
        end
      end
    end
  end
end
