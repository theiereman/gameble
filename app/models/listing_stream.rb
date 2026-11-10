# The listings an open Annonce refreshes on, one public stream per listing named by its token: it carries a signal and nothing else.
module ListingStream
  EVENTS = [
    Game::Market::BidPlaced, Game::Market::AuctionSold, Game::Market::AuctionUnsold, Game::Market::ListingCancelled, Game::Market::ListingWithdrawn
  ].freeze

  BATCHES = :listing_stream_batches
  BATCH = AfterCommitBatch.new(BATCHES) { |listing_ids| ListingStreamJob.perform_later(listing_ids.uniq) }

  class << self
    def streamables(token) = [ "market-listing", token ]

    def call(event)
      BATCH.add([ event.data[:listing_id] ])
    end
  end
end
