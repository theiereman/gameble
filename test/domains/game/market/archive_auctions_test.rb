require "test_helper"
require_relative "../../../support/market"
require_relative "../../../support/market_auctions"

class Game::Market::ArchiveAuctionsTest < ActiveSupport::TestCase
  include MarketAuctions
  include MarketSettings

  setup do
    @settings = open_market!
    @epic = catalog_card_seasons(:portal_one)
    @legendary = catalog_card_seasons(:legendary_card_one)
    @winner = accounts_players(:moderator)
    { @epic => 2, @legendary => 1, catalog_card_seasons(:rare_card_one) => 3 }.each do |card, quantity|
      Game::Market::ArchiveStock.create!(card_season_id: card.id, quantity:)
    end
  end

  def open(card = @epic) = Game::Market::OpenArchiveAuction.new.call(card_season_id: card.id)

  def close(listing) = Game::Market::CloseAuction.new.call(player: nil, listing_id: listing.id)

  def stock(card) = Game::Market::ArchiveStock.find_by(card_season_id: card.id)&.quantity

  test "the week's picks are the Epics and the Legendary in stock, none once the week's auctions are open" do
    assert_equal [ @epic.id, @legendary.id ], Game::Market::ArchiveAuctionPicks.call

    open
    assert_empty Game::Market::ArchiveAuctionPicks.call
    assert_equal [ @epic.id, @legendary.id ], Game::Market::ArchiveAuctionPicks.call(now: 1.week.from_now)
  end

  test "an auction of the Archives has no seller, opens at the reserve for 48 hours and takes its copy from the stock" do
    listing = open.value!

    assert_nil listing.seller_id
    assert_equal [ 3_300, 3_300, 48 ], [ listing.starting_price, listing.current_price, listing.duration_hours ]
    assert_equal 1, stock(@epic)
    assert_equal 0, Game::Market::LedgerEntry.where(listing_id: listing.id).count
    assert_equal :not_in_shop, open(catalog_card_seasons(:rare_card_one)).failure

    Game::Market::ArchiveDeposit.create!(player_id: accounts_players(:player).id, card_season_id: @epic.id, quantity: 2)
    Game::Market::SumArchiveStocks.new.call
    assert_equal 1, stock(@epic), "the stocks summed again leave out the copy the auction holds"
  end

  test "a sold auction of the Archives gives the copy to the winner and destroys the price" do
    listing = open(@legendary).value!
    fund!(@winner, 10_000)
    lead!(listing, @winner, 9_000, price: 8_400)
    listing.update!(ends_at: 1.minute.ago)

    assert close(listing).success?

    assert_equal [ "sold", 8_400 ], listing.reload.values_at(:status, :final_price)
    assert_equal 1, Game::Holding.find_by!(player_id: @winner.id, card_season_id: @legendary.id).quantity
    assert_equal [ 1_600, 0 ], Game::Market::Wallet.find_by!(player_id: @winner.id).values_at(:available, :committed)
    assert_equal(-8_400, Game::Market::LedgerEntry.where(listing_id: listing.id, kind: "archive_purchase").sum(:available_delta))
    assert_nil stock(@legendary)
  end

  test "an unsold auction of the Archives puts its copy back in the stock" do
    listing = open(@legendary).value!
    listing.update!(ends_at: 1.minute.ago)

    assert close(listing).success?

    assert_equal "unsold", listing.reload.status
    assert_equal 1, stock(@legendary)
    assert_empty Game::Market::Notice.where(listing_id: listing.id)
  end

  test "a player bids on an auction of the Archives like any other" do
    listing = open.value!
    fund!(@winner, 5_000)

    assert Game::Market::PlaceBid.new.call(player: @winner, listing_id: listing.id, maximum: 4_000).success?
    assert_equal @winner.id, listing.reload.leader_id
  end

  test "the Monday job opens the week's picks once, and nothing while the market is closed" do
    close_market!
    Game::OpenArchiveAuctionsJob.perform_now
    assert_empty Game::Market::Listing.of_archives

    open_market!
    2.times { Game::OpenArchiveAuctionsJob.perform_now }
    assert_equal [ @epic.id, @legendary.id ].sort, Game::Market::Listing.of_archives.pluck(:card_season_id).sort
  end
end
