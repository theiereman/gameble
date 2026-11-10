require "test_helper"

class Game::Market::BidCommitmentFixtureTest < ActiveSupport::TestCase
  Listing = Struct.new(:buy_now_price)
  Player = Struct.new(:id)

  ROWS = JSON.parse(File.read(Rails.root.join("test/fixtures/files/bid_commitments.json")))

  test "each row of the browser's fixture is the amount the server holds" do
    ROWS.each do |row|
      player = Player.new(1)
      leader = Game::Market::BidTerms.lead_of(1, row["own_maximum"]) if row["own_maximum"]
      terms = Game::Market::BidTerms.new(listing: Listing.new(row["buy_now"]), player:, maximum: row["maximum"], settings: nil, now: nil, leader:, displaced: nil)

      assert_equal row["needed"], terms.needed, row.inspect
    end
  end
end
