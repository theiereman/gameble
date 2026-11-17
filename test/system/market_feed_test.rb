require "application_system_test_case"
require_relative "../support/market"
require_relative "../support/market_feed"

class MarketFeedSystemTest < ApplicationSystemTestCase
  include MarketFeed
  include MarketSettings

  setup do
    open_market!(first_opened_at: 1.day.ago)
    @buyer = accounts_players(:moderator)
    @buyer.update!(persona_name: "Sam")
    sale_entry!(@buyer, catalog_card_seasons(:legendary_card_one), 40_000)
  end

  test "a sale shows under everything and under sales with a linked name, and a private buyer's name has no link" do
    visit feed_path(locale: :en)
    assert_selector ".feed__entry .feed__headline", text: /Bought for\s*40,000\s*Golden Crown/i
    assert_selector ".feed__who a.player-name--linked", text: "Sam"

    click_on "Sales"
    assert_selector ".feed__filter[aria-current=true]", text: /sales/i
    assert_selector ".feed__tag--sale", text: /\Asale\z/i

    @buyer.update!(visibility: "private")
    visit feed_path(locale: :en, filter: "sales")
    assert_selector ".feed__who .player-name", text: "Sam"
    assert_no_selector ".feed__who a.player-name--linked"
  end
end
