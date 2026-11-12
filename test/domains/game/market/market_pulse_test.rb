require "test_helper"
require_relative "../../../support/market"
require_relative "../../../support/market_listings"

class Game::Market::MarketPulseTest < ActiveSupport::TestCase
  include MarketListings
  include MarketSettings

  setup do
    open_market!(first_opened_at: 1.day.ago)
    @seller = accounts_players(:player)
    @cards = %i[common_card_one uncommon_card_one rare_card_one].map { catalog_card_seasons(it) }
  end

  test "it counts the open listings and lists those ending within the hour, soonest first" do
    later = listing!(seller: @seller, card_season: @cards[0], ends_at: 50.minutes.from_now)
    sooner = listing!(seller: @seller, card_season: @cards[1], ends_at: 10.minutes.from_now)
    listing!(seller: @seller, card_season: @cards[2], hours: 24)
    listing!(seller: @seller, card_season: @cards[2], status: "sold", ends_at: 5.minutes.from_now)

    pulse = Game::Market::MarketPulse.call(locale: :en)

    assert_equal 3, pulse.open
    assert_equal 2, pulse.ending_soon
    assert_equal [ sooner.token, later.token ], pulse.soonest.map(&:token)
  end

  test "the list stops at its limit" do
    3.times { listing!(seller: @seller, card_season: @cards[it], ends_at: (it + 1).minutes.from_now) }

    assert_equal 2, Game::Market::MarketPulse.call(locale: :en, limit: 2).soonest.size
  end
end
