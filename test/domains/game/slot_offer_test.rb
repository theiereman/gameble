require "test_helper"
require_relative "../../support/market"

# The next slot on offer: only at a free limit below the ceiling, priced by the settings version in force.
class Game::SlotOfferTest < ActiveSupport::TestCase
  include MarketSettings

  test "at a free limit the next slot is offered at its price" do
    open_market!(slot_price_goal_7: 1_200)

    assert_equal Game::SlotOffer::Offer.new(kind: :goal, slot: 7, price: 1_200), Game::SlotOffer.call(:goal, limit: 6, used: 6)
    assert_equal 4, Game::SlotOffer.call(:deck, limit: 3, used: 4).slot
  end

  test "under the limit, at the ceiling or before any settings version, nothing is offered" do
    close_market!

    assert_nil Game::SlotOffer.call(:custom_set, limit: 5, used: 4)
    assert_nil Game::SlotOffer.call(:custom_set, limit: 10, used: 10)
    assert_nil Game::SlotOffer.call(:deck, limit: 5, used: 5)
    assert Game::SlotOffer.call(:custom_set, limit: 5, used: 5)

    forget_market!
    assert_nil Game::SlotOffer.call(:custom_set, limit: 5, used: 5)
  end
end
