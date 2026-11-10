require "test_helper"
require_relative "../support/holdings"
require_relative "../support/market"
require_relative "../support/market_listings"
require_relative "../support/market_auctions"
require_relative "../support/market_bidding"

# The signal an open Annonce refreshes on: one public stream per listing named by its token, sent by a job once the transaction commits.
class ListingStreamTest < ActiveSupport::TestCase
  include ActionCable::TestHelper
  include ActiveJob::TestHelper
  include Holdings
  include MarketAuctions
  include MarketBidding
  include MarketListings
  include MarketSettings

  setup do
    @seller = accounts_players(:player)
    @first = accounts_players(:moderator)
    @second = accounts_players(:administrator)
    @card = catalog_card_seasons(:common_card_one)
    open_market!(increment_basis_points: 500, soft_close_seconds: 180)
    hold(@seller, @card.id, 2, reserved: 2)
    @listing = listing!(seller: @seller, card_season: @card, starting_price: 20_000, ends_at: 1.day.from_now)
    [ @first, @second ].each { fund!(it, 100_000) }
  end

  def jobs = enqueued_jobs.select { it[:job] == ListingStreamJob }

  def listing_ids = jobs.flat_map { ActiveJob::Arguments.deserialize(it[:args]).first }

  test "the stream is named by the token, with no database id" do
    assert_equal [ "market-listing", "abc" ], ListingStream.streamables("abc")
  end

  test "every event of a listing is heard" do
    expected = %w[BidPlaced AuctionSold AuctionUnsold ListingCancelled ListingWithdrawn].map { "Game::Market::#{it}" }

    assert_equal expected, ListingStream::EVENTS.map(&:name)
  end

  test "a bid enqueues one job for its listing after the commit, and a refused bid none" do
    assert_enqueued_jobs(1, only: ListingStreamJob) { bid(@first, 30_000) }
    assert_equal [ @listing.id ], listing_ids

    clear_enqueued_jobs
    assert_no_enqueued_jobs(only: ListingStreamJob) { bid(@second, 10) }
  end

  test "nothing is enqueued when the transaction rolls back" do
    ActiveRecord::Base.transaction(requires_new: true) do
      bid(@first, 30_000)
      raise ActiveRecord::Rollback
    end

    assert_empty jobs
  end

  test "a sale, a close without a bid and a cancellation each enqueue for their listing" do
    other = listing!(seller: @seller, card_season: @card, starting_price: 20_000, ends_at: 1.day.from_now)
    assert Game::Market::CancelListing.new.call(player: @seller, listing_id: other.id).success?
    assert_equal [ other.id ], listing_ids

    clear_enqueued_jobs
    @listing.update_columns(ends_at: 1.minute.ago)
    assert Game::Market::CloseAuction.new.call(player: @seller, listing_id: @listing.id).success?
    assert_equal [ @listing.id ], listing_ids
  end

  test "the job sends one signal per listing on the stream named by its token and nothing else" do
    ListingStreamJob.perform_now([ @listing.id, @listing.id ])

    message = ActiveSupport::JSON.decode(broadcasts("market-listing:#{@listing.token}").sole)
    stream = Nokogiri::HTML5.fragment(message).at_css("turbo-stream")
    assert_equal [ "gameble-event", "listing-updated" ], [ stream["action"], stream["event"] ]
    assert_empty stream.at_css("template").children
    assert_equal 1, broadcasts("market-listing:#{@listing.token}").size
  end
end
