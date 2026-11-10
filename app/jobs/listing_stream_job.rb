class ListingStreamJob < ApplicationJob
  queue_as :default

  SIGNAL = %(<turbo-stream action="gameble-event" event="listing-updated"><template></template></turbo-stream>)

  def perform(listing_ids)
    Game::Market::ListingTokens.call(listing_ids).each do |token|
      Turbo::StreamsChannel.broadcast_stream_to(*ListingStream.streamables(token), content: SIGNAL)
    end
  end
end
