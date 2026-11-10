require "test_helper"
require_relative "../support/market"
require_relative "../support/market_feed"
require_relative "../support/steam_sign_in"

class FeedSalesTest < ActionDispatch::IntegrationTest
  include MarketFeed
  include MarketSettings
  include SteamSignIn

  setup do
    open_market!(first_opened_at: 1.day.ago)
    @buyer = accounts_players(:moderator)
    @buyer.update!(persona_name: "Sam")
    @legendary = catalog_card_seasons(:legendary_card_one)
    sale_entry!(@buyer, @legendary, 40_000)
  end

  def sentence = css_select(".feed__entry .feed__sentence").first.text.squish

  test "a sale reads the buyer, the game and the amount under the whole feed and under Sales, with its tag" do
    [ nil, "sales" ].each do |filter|
      get feed_path(locale: :en, filter:)

      assert_response :success
      assert_match(/\ASam bought Golden Crown for .*40,000/, sentence)
      assert_select ".feed__entry .picoin-amount", 1
      assert_select ".feed__tag--sale", "Sale"
    end
    assert_select ".feed__filter[aria-current]", "Sales"
  end

  test "the French sentence and filter" do
    get feed_path(locale: :fr, filter: "sales")

    assert_select ".feed__filter[aria-current]", "Ventes"
    assert_select ".feed__tag--sale", "Vente"
    assert_match(/\ASam a acheté Couronne d'or pour /, sentence)
  end

  test "the buyer's name links for a viewer allowed on the profile and not for a private buyer" do
    get feed_path(locale: :en)
    assert_select ".feed__sentence a.player-name--linked", text: "Sam"

    @buyer.update!(visibility: "private")
    get feed_path(locale: :en)
    assert_select ".feed__entry", 1
    assert_select ".feed__sentence a.player-name--linked", 0
    assert_select ".feed__sentence .player-name", text: "Sam"
  end

  test "a banned buyer's sale is gone" do
    @buyer.update_columns(banned_at: Time.current)

    get feed_path(locale: :en, filter: "sales")

    assert_select ".feed__entry", 0
  end

  test "the friends tab keeps a friend's purchase" do
    sign_in_new_player("76561197960287990")
    me = Accounts::Player.find_by!(steam_id: "76561197960287990")
    Game::Friendship.create!(low_player_id: [ me.id, @buyer.id ].min, high_player_id: [ me.id, @buyer.id ].max)

    get feed_path(locale: :en, tab: "friends")

    assert_select ".feed__tag--sale", 1
  end

  test "the hub ticker never shows a sale" do
    assert_not_includes LiveStream::TICKER_KINDS, "sale"
    assert_empty LiveStream.ticker_items
  end
end
