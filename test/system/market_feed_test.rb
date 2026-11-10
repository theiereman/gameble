require "application_system_test_case"
require_relative "../support/steam_sign_in"
require_relative "../support/market"
require_relative "../support/market_feed"

# A notable sale shows in the activity feed under TOUT and VENTES, with its buyer's name linked only when the viewer may open the profile, and never in the hub ticker.
class MarketFeedSystemTest < ApplicationSystemTestCase
  include MarketFeed
  include MarketSettings
  include SteamSignIn

  setup do
    open_market!(first_opened_at: 1.day.ago)
    @buyer = accounts_players(:moderator)
    @buyer.update!(persona_name: "Sam")
    sale_entry!(@buyer, catalog_card_seasons(:legendary_card_one), 40_000)
  end

  test "a sale shows under everything and under sales with a linked name, and a private buyer's name has no link" do
    visit feed_path(locale: :en)
    assert_selector ".feed__entry .feed__sentence", text: /Sam bought Golden Crown for/
    assert_selector ".feed__sentence a.player-name--linked", text: "Sam"

    click_on "Sales"
    assert_selector ".feed__filter[aria-current=true]", text: "Sales"
    assert_selector ".feed__tag--sale", text: "Sale"

    @buyer.update!(visibility: "private")
    visit feed_path(locale: :en, filter: "sales")
    assert_selector ".feed__sentence .player-name", text: "Sam"
    assert_no_selector ".feed__sentence a.player-name--linked"
  end

  test "the hub ticker never shows the sale" do
    mock_steam_sign_in(accounts_players(:player).steam_id)
    visit home_path(locale: :en)
    click_steam_sign_in
    assert_signed_in

    assert_no_selector "#live-ticker .ticker__sentence", text: /bought/, visible: :all
  end
end
