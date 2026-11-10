require "test_helper"
require_relative "../support/market"
require_relative "../support/market_feed"

# A notable sale reaches the live feed: one notice per sale after commit, one prepend per locale with no link on a private buyer, no ticker.
class LiveFeedSaleTest < ActiveSupport::TestCase
  include ActionCable::TestHelper
  include MarketFeed
  include MarketSettings

  setup do
    open_market!(first_opened_at: 1.day.ago)
    @buyer = accounts_players(:moderator)
    @buyer.update!(persona_name: "Sam")
    @legendary = catalog_card_seasons(:legendary_card_one)
  end

  def received(locale)
    Nokogiri::HTML5.fragment(ActiveSupport::JSON.decode(broadcasts(LiveStream.feed_streamables(locale).join(":")).sole))
  end

  def template(fragment, action, target)
    Nokogiri::HTML5.fragment(fragment.css("turbo-stream[action='#{action}'][target='#{target}']").sole.at_css("template").inner_html)
  end

  test "an auction sold names its listing in a notice" do
    event = Game::Market::AuctionSold.new(data: { listing_id: 12 })

    assert_equal [ { listing_id: 12 } ], LiveStream.notices(event)
  end

  test "a sale is prepended to the feed in each locale and never queued for the ticker" do
    listing = sale_entry!(@buyer, @legendary, 40_000)

    LiveFeedJob.perform_now([ { listing_id: listing.id } ])

    feed = received(:en)
    assert_equal "Sam", template(feed, "prepend", "feed-entries").at_css(".feed__sentence .player-name").text
    assert template(feed, "prepend", "feed-entries").at_css(".feed__tag--sale")
    assert_empty feed.css("turbo-stream[target='live-ticker-queue']")
    assert_match(/Sam a acheté/, template(received(:fr), "prepend", "feed-entries").at_css(".feed__sentence").text.squish)
  end

  test "a public buyer's name links in the broadcast" do
    listing = sale_entry!(@buyer, @legendary, 40_000)

    LiveFeedJob.perform_now([ { listing_id: listing.id } ])

    assert template(received(:en), "prepend", "feed-entries").at_css(".feed__sentence a.player-name--linked")
  end

  test "a private buyer's name has no link in the broadcast" do
    @buyer.update!(visibility: "private")
    listing = sale_entry!(@buyer, @legendary, 40_000)

    LiveFeedJob.perform_now([ { listing_id: listing.id } ])

    sentence = template(received(:en), "prepend", "feed-entries").at_css(".feed__sentence")
    assert_nil sentence.at_css("a.player-name--linked")
    assert_equal "Sam", sentence.at_css(".player-name").text
  end

  test "a sale below the threshold broadcasts nothing" do
    listing = sale_entry!(@buyer, catalog_card_seasons(:common_card_one), 2_000)

    assert_no_broadcasts(LiveStream.feed_streamables(:en).join(":")) { LiveFeedJob.perform_now([ { listing_id: listing.id } ]) }
  end
end
