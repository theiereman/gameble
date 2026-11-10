require "test_helper"
require_relative "../../../support/holdings"
require_relative "../../../support/market"
require_relative "../../../support/market_listings"
require_relative "../../../support/market_auctions"

class Game::Market::CloseAuctionEventsTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper
  include Holdings
  include MarketAuctions
  include MarketListings
  include MarketSettings

  setup do
    @seller = accounts_players(:player)
    @winner = accounts_players(:moderator)
    @card = catalog_card_seasons(:common_card_one)
    open_market!
    hold(@seller, @card.id, 1, reserved: 1)
    @listing = listing!(seller: @seller, card_season: @card, starting_price: 20_000, ends_at: 1.minute.ago)
    fund!(@winner, 50_000)
    lead!(@listing, @winner, 40_000, price: 31_500)
  end

  def close = Game::Market::CloseAuction.new.call(player: @seller, listing_id: @listing.id)

  def sold_event = Game::Market::AuctionSold.new(data: { listing_id: @listing.id, seller_id: @seller.id, winner_id: @winner.id, card_season_id: @card.id,
    final_price: 31_500, surplus: 8_500, outbid_player_id: nil, outbid_released: 0 })

  test "goals and achievements hear the sale for the winner only" do
    dropped = []
    achieved = []
    Game::Goal.stub(:drop_reached, ->(ids) { dropped << ids }) do
      Game::GrantAchievementsJob.stub(:perform_later, ->(id) { achieved << id }) do
        Game::Handlers::GoalsReached.call(sold_event)
        Game::Handlers::Achievements.call(sold_event)
      end
    end

    assert_equal [ [ @winner.id ] ], dropped
    assert_equal [ @winner.id ], achieved
  end

  test "the weekly contribution is not fed by a sale" do
    assert_no_difference -> { Game::WeeklyContribution.count } do
      close
    end
  end

  test "balance notices are enqueued after the commit" do
    assert_enqueued_with(job: PlayerStreamJob) { close }

    notices = enqueued_jobs.select { it[:job] == PlayerStreamJob }.flat_map { it[:args].first }.select { it["balance"] }
    assert_equal [ @seller.id, @winner.id ].sort, notices.map { it["player_id"] }.sort
  end

  test "no notice survives a rollback" do
    ActiveRecord::Base.transaction(requires_new: true) do
      close
      raise ActiveRecord::Rollback
    end

    assert_empty enqueued_jobs.select { it[:job] == PlayerStreamJob }
  end
end
