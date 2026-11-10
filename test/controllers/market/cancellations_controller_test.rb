require "test_helper"
require_relative "../../support/steam_sign_in"
require_relative "../../support/holdings"
require_relative "../../support/market"
require_relative "../../support/market_listings"
require_relative "../../support/market_auctions"
require_relative "../../support/counting_rate_limit"

class Market::CancellationsControllerTest < ActionDispatch::IntegrationTest
  include CountingRateLimit
  include Holdings
  include MarketAuctions
  include MarketListings
  include MarketSettings
  include SteamSignIn

  setup do
    @seller = accounts_players(:player)
    @other = accounts_players(:moderator)
    @card = catalog_card_seasons(:common_card_one)
    open_market!(first_opened_at: 1.day.ago)
    hold(@seller, @card.id, 1, reserved: 1)
    @listing = listing!(seller: @seller, card_season: @card, starting_price: 20_000, ends_at: 1.day.from_now)
  end

  def cancel(token: @listing.token, locale: :en, **params) = post(market_listing_cancellation_path(locale:, token:), params:)

  def nothing_moves(&)
    assert_no_difference([ -> { Game::Market::LedgerEntry.count }, -> { Game::Holding.sum(:reserved) } ], &)
    assert_equal "open", @listing.reload.status
  end

  test "a visitor is refused with sign_in_required and nothing changes" do
    nothing_moves { cancel }
    assert_response :see_other

    nothing_moves { post market_listing_cancellation_path(locale: :en, token: @listing.token, format: :json) }
    assert_response :unauthorized
    assert_equal "sign_in_required", response.parsed_body.dig("error", "code")
  end

  test "another player is refused as forbidden and nothing changes" do
    sign_in(@other)

    nothing_moves { cancel }

    assert_response :forbidden
  end

  test "an unknown token is a 404" do
    sign_in(@seller)

    cancel(token: "A" * 24)

    assert_response :not_found
  end

  test "the seller cancels from MES VENTES and lands on it with the notice and the next row" do
    sign_in(@seller)

    assert_no_difference -> { Game::Market::LedgerEntry.count } do
      cancel(return_to: "sales", landing: "NEXTROWTOKEN")
    end

    assert_redirected_to market_my_sales_path(locale: :en, landing: "NEXTROWTOKEN")
    assert_equal "Sale cancelled.", flash[:notice]
    assert_equal "cancelled", @listing.reload.status
    assert_equal 0, Game::Holding.find_by!(player_id: @seller.id, card_season_id: @card.id).reserved
  end

  test "the last row sends an empty landing so the group heading takes focus" do
    sign_in(@seller)

    cancel(return_to: "sales", landing: "")

    assert_redirected_to market_my_sales_path(locale: :en, landing: "")
  end

  test "the seller cancels from the Annonce and returns to it" do
    sign_in(@seller)

    cancel(return_to: "annonce", landing: "NEXTROWTOKEN")

    assert_redirected_to market_listing_path(locale: :en, token: @listing.token)
    assert_equal "Sale cancelled.", flash[:notice]
  end

  test "any other return_to is treated as sales, and a landing that is not a token is dropped" do
    sign_in(@seller)

    cancel(return_to: "https://example.com", landing: "<script>")

    assert_redirected_to market_my_sales_path(locale: :en)
  end

  test "a bid standing refuses with the Copy deck line, in English and in French" do
    fund!(@other, 100_000)
    lead!(@listing, @other, 30_000)
    sign_in(@seller)

    nothing_moves { cancel }
    assert_redirected_to market_my_sales_path(locale: :en)
    assert_equal "A bid just arrived. The sale can no longer be cancelled.", flash[:alert]

    nothing_moves { cancel(locale: :fr) }
    assert_equal "Une offre vient d'arriver. La vente ne peut plus être annulée.", flash[:alert]
  end

  test "an ended listing refuses and goes back to the Annonce when the form came from it" do
    @listing.update_columns(status: "unsold")
    sign_in(@seller)

    cancel(return_to: "annonce")

    assert_redirected_to market_listing_path(locale: :en, token: @listing.token)
    assert_equal "This auction has ended.", flash[:alert]
  end

  test "a closed market still accepts a cancel" do
    close_market!(first_opened_at: 1.day.ago)
    sign_in(@seller)

    cancel

    assert_equal "cancelled", @listing.reload.status
  end

  test "no redirect carries a database id" do
    sign_in(@seller)

    cancel(return_to: "annonce")

    assert_not_includes URI(response.location).path.split("/"), @listing.id.to_s
  end

  test "the twenty-first cancel of a minute is throttled" do
    sign_in(@seller)

    with_counting_rate_limit(Market::CancellationsController) { 21.times { cancel(token: "A" * 24) } }

    assert_redirected_to market_my_sales_path(locale: :en)
  end
end
