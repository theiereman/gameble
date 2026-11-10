require "test_helper"
require_relative "../../support/holdings"
require_relative "../../support/market"
require_relative "../../support/market_listings"
require_relative "../../support/market_auctions"

class Game::CloseDueAuctionsJobTest < ActiveSupport::TestCase
  include Holdings
  include MarketAuctions
  include MarketListings
  include MarketSettings

  setup do
    @seller = accounts_players(:player)
    open_market!
    @cards = [ catalog_card_seasons(:common_card_one), catalog_card_seasons(:portal_one), catalog_card_seasons(:rare_card_one) ]
    @cards.each { hold(@seller, it.id, 1, reserved: 1) }
  end

  def due!(card, ends_at: 1.minute.ago, status: "open") = listing!(seller: @seller, card_season: card, ends_at:, status:)

  test "a listing that raises does not stop the others and is reported with its id" do
    first, second, third = @cards.map { due!(it) }
    original = Game::Market::CloseAuction.instance_method(:call)
    failing = ->(**arguments) { arguments[:listing_id] == second.id ? raise("boom") : original.bind(Game::Market::CloseAuction.new).call(**arguments) }

    report = assert_error_reported(RuntimeError) do
      Game::Market::CloseAuction.stub(:new, -> { Struct.new(:call).new(failing) }) { Game::CloseDueAuctionsJob.perform_now }
    end

    assert_equal second.id, report.context[:listing_id]
    assert_equal %w[unsold open unsold], [ first, second, third ].map { it.reload.status }
  end

  test "a second run changes nothing" do
    due!(@cards.first)
    Game::CloseDueAuctionsJob.perform_now

    assert_no_difference([ -> { Game::Market::LedgerEntry.count }, -> { Game::Holding.sum(:reserved) }, -> { Game::Market::Listing.where(status: "unsold").count } ]) do
      assert_no_error_reported { Game::CloseDueAuctionsJob.perform_now }
    end
  end

  test "an undue and a closed listing are left alone" do
    undue = due!(@cards.first, ends_at: 1.hour.from_now)
    closed = due!(@cards.second, status: "sold").tap { it.update_columns(sold_at: Time.current, final_price: 1_300) }

    assert_no_difference -> { Game::Holding.sum(:reserved) } do
      Game::CloseDueAuctionsJob.perform_now
    end

    assert_equal %w[open sold], [ undue.reload.status, closed.reload.status ]
  end
end
