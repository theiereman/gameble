require "test_helper"
require_relative "../../support/steam_sign_in"
require_relative "../../support/holdings"
require_relative "../../support/market"
require_relative "../../support/market_listings"
require_relative "../../support/market_auctions"
require_relative "../../support/market_bidding"
require_relative "../../support/counting_rate_limit"

class Market::BidsControllerTest < ActionDispatch::IntegrationTest
  include CountingRateLimit
  include Holdings
  include MarketAuctions
  include MarketBidding
  include MarketListings
  include MarketSettings
  include SteamSignIn

  setup do
    @seller = accounts_players(:player)
    @first = accounts_players(:moderator)
    @second = accounts_players(:administrator)
    @card = catalog_card_seasons(:common_card_one)
    open_market!(first_opened_at: 1.day.ago, increment_basis_points: 500, soft_close_seconds: 180)
    hold(@seller, @card.id, 1, reserved: 1)
    @listing = listing!(seller: @seller, card_season: @card, starting_price: 20_000, buy_now_price: 60_000, ends_at: 1.day.from_now)
    [ @first, @second ].each { fund!(it, 100_000) }
  end

  def post_bid(maximum, locale: :en, token: @listing.token, **extra)
    post market_listing_bids_path(locale:, token:), params: { maximum:, drawn_minimum: "20000", **extra }, as: :turbo_stream
  end

  def region = css_select("turbo-stream[action=replace][target=annonce-bid]")

  def answer_title = css_select("#annonce-answer-heading").first&.text

  def refusal = css_select("p#annonce-error, p.market-bid__refusal").first&.text

  test "a visitor is refused and nothing is placed" do
    assert_no_difference -> { Game::Market::Bid.count } do
      post_bid("30000")
    end

    assert_response :unauthorized
  end

  test "a banned bidder is refused" do
    sign_in(@second)
    @second.update_columns(banned_at: Time.current)

    assert_no_difference -> { Game::Market::Bid.count } do
      post_bid("30000")
    end

    assert_response :unauthorized
  end

  test "the seller's forged post is refused inline, with no form" do
    sign_in(@seller)
    post_bid("30000")

    assert_response :unprocessable_content
    assert_equal "You cannot bid on your own listing.", refusal
    assert_select "turbo-stream[target=annonce-bid] form", false
  end

  test "an unknown token is a 404" do
    sign_in(@second)
    post_bid("30000", token: "A" * 24)

    assert_response :not_found
  end

  test "a first bid answers that the bidder leads, focuses the heading and redraws the raising form" do
    sign_in(@second)
    post_bid("30000")

    assert_response :success
    assert_equal 1, region.size
    assert_equal "YOU ARE LEADING", answer_title
    assert_select "#annonce-bid[data-focus=heading]"
    assert_select "#annonce-answer .market-answer__body", /Current price/
    assert_select "#annonce-answer .picoin-amount__figure", text: "20,000"
    assert_select "#annonce-answer .picoin-amount__figure", text: "30,000"
    assert_select "#annonce-minimum", /More than your current maximum, 30,000/
    assert_select "input#annonce-maximum[value='']"
    assert_select "[data-annonce-field-answered-value=true]"
    assert_equal [ 70_000, 30_000 ], figures(@second)
  end

  test "a bid beaten at once names the new price and minimum, focuses the field and shows no other maximum" do
    bid(@first, 30_000)
    sign_in(@second)
    post_bid("25000", drawn_minimum: "21000")

    assert_equal "ANOTHER PLAYER HAD A HIGHER MAXIMUM", answer_title
    assert_select "#annonce-bid[data-focus=field]"
    assert_select "#annonce-answer .picoin-amount__figure", text: "26,300"
    assert_select "#annonce-answer .picoin-amount__figure", text: "27,700"
    assert_select "input#annonce-maximum[value=''][aria-describedby~=annonce-answer]"
    assert_no_match(/30,000|30000/, response.body)
  end

  test "an equal maximum reads its own title" do
    bid(@first, 30_000)
    sign_in(@second)
    post_bid("30000", drawn_minimum: "21000")

    assert_equal "ANOTHER PLAYER HAD ALREADY OFFERED THIS MAXIMUM", answer_title
  end

  test "a leader's raise keeps the price" do
    bid(@first, 30_000)
    sign_in(@first)
    post_bid("35000", drawn_minimum: "30001")

    assert_equal "MAXIMUM RAISED", answer_title
    assert_select "#annonce-answer .picoin-amount__figure", text: "35,000"
    assert_equal [ 65_000, 35_000 ], figures(@first)
  end

  test "a maximum at the buy-now price buys and answers the buyer's outcome" do
    sign_in(@second)
    post_bid("60000")

    assert_response :success
    assert_select "#annonce-bid[data-focus=heading]"
    assert_select "#annonce-bid h2#listing-outcome-heading", "YOU BOUGHT TIN SOLDIER"
    assert_select "#annonce-bid a", "SEE THE CARD"
    assert_select "#annonce-bid form", false
    assert_equal "sold", @listing.reload.status
  end

  test "below the minimum names it, and says the price changed when the drawn minimum differs" do
    bid(@first, 30_000)
    sign_in(@second)

    post_bid("15000", drawn_minimum: "21000")
    assert_response :unprocessable_content
    assert_equal "At least 21,000 is needed.", refusal
    assert_select "input#annonce-maximum[value='15000'][aria-invalid=true][aria-describedby~=annonce-error]"

    post_bid("15000", drawn_minimum: "20000")
    assert_equal "The price just changed. At least 21,000 is needed now.", refusal

    post_bid("15000", locale: :fr, drawn_minimum: "20000")
    assert_equal "Le prix vient de changer. Il faut maintenant au moins 21\u00a0000.", refusal
  end

  test "more than available names the fresh figure and keeps the text" do
    sign_in(@second)
    post_bid("100001")

    assert_equal "You can commit at most 100,000.", refusal
    assert_select "input#annonce-maximum[value='100001']"
  end

  test "an invalid amount is refused with the text kept" do
    sign_in(@second)
    post_bid("3x0")

    assert_equal "Enter a whole number of PiCoins, above zero.", refusal
    assert_select "input#annonce-maximum[value='3x0']"
  end

  test "a closed market reads its text" do
    sign_in(@second)
    close_market!
    post_bid("30000")
    assert_equal "The market is closed for now.", refusal
  end

  test "an auction that ended replaces the region with the outcome and the not-recorded line" do
    sign_in(@second)
    @listing.update_columns(ends_at: 1.minute.ago)
    post_bid("30000")

    assert_response :unprocessable_content
    assert_select "#annonce-bid .market-outcome--closing", "Closing…"
    assert_select "#annonce-bid .market-bid__note", "Your amount was not recorded."
    assert_select "#annonce-bid[data-focus=heading]"
    assert_select "#annonce-bid form", false
  end

  test "the 21st bid of a minute is throttled with the amount kept" do
    sign_in(@second)

    with_counting_rate_limit(Market::BidsController) do
      20.times { post_bid("1") }
      assert_response :unprocessable_content
      post_bid("1")
    end

    assert_response :too_many_requests
    assert_equal "Too many bids at once. Wait a moment.", refusal
    assert_select "input#annonce-maximum[value='1']"
  end

  test "a plain form post redirects to the Annonce" do
    sign_in(@second)
    post market_listing_bids_path(locale: :en, token: @listing.token), params: { maximum: "30000" }

    assert_redirected_to market_listing_path(locale: :en, token: @listing.token)
    assert_response :see_other
  end

  test "no response carries a database id" do
    sign_in(@second)
    post_bid("30000")

    assert_no_match(/(?:id|listing|bid)[-_=:"]#{@listing.id}\b/, response.body)
    assert_select "[style]", false
  end
end
