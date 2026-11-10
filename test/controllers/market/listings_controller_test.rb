require "test_helper"
require_relative "../../support/market"
require_relative "../../support/market_listings"
require_relative "../../support/steam_sign_in"

class Market::ListingsControllerTest < ActionDispatch::IntegrationTest
  include MarketListings
  include MarketSettings
  include SteamSignIn

  setup do
    open_market!(first_opened_at: 1.day.ago)
    @seller = accounts_players(:player)
    @seller.update_columns(persona_name: "Alice")
    @listing = listing!(seller: @seller, card_season: catalog_card_seasons(:rare_card_one), starting_price: 7_800, buy_now_price: 30_000,
      ends_at: (2.hours + 14.minutes + 30.seconds).from_now)
  end

  def annonce(locale: :en) = get(market_listing_path(locale:, token: @listing.token))

  test "a visitor reads the Annonce: card, seller, price, time left with the end time and the buy-now" do
    annonce

    assert_response :success
    assert_select "h1#market-listing-heading[tabindex='-1'][autofocus]", "Blue Depths"
    assert_select ".market-listing__price .picoin-amount__figure", "7,800"
    assert_select ".market-listing__price[aria-label='7,800 PiCoins']"
    assert_select ".market-listing__time", "2 h 14"
    assert_select ".market-listing__time--soon", false
    assert_select ".market-listing__ends time[datetime]"
    assert_select ".market-listing__buy-now[aria-label='30,000 PiCoins']"
    assert_select ".market-listing__fact a.player-name--linked[href=?]", brother_path(locale: :en, token: @seller.token), "Alice"
    assert_select "[data-controller~=listing-clock][data-listing-clock-seconds-value]"
    assert_select "[data-listing-clock-minutes-template-value='%{minutes} min']"
    assert_select ".balance-chip", false
  end

  test "the way back leads to the market" do
    annonce

    assert_select "a.top-bar__phone-back[href=?]", market_path(locale: :en), /Market/
  end

  test "an Annonce under an hour has the alert modifier" do
    @listing.update_columns(ends_at: 18.minutes.from_now + 30.seconds)
    annonce

    assert_select ".market-listing__time.market-listing__time--soon", "18 min"
  end

  test "the Annonce reads in French" do
    annonce(locale: :fr)

    assert_select ".market-listing__label", text: "PRIX ACTUEL"
    assert_select ".market-listing__label", text: "FIN DANS"
    assert_select ".market-listing__fact dt", text: "Vendeur"
    assert_select ".top-bar__phone-back", /Marché/
  end

  test "no buy-now means no buy-now figure, and a leader is shown" do
    @listing.update_columns(buy_now_price: nil, leader_id: accounts_players(:moderator).id, leader_maximum: 8_500, current_price: 8_000)
    annonce

    assert_select ".market-listing__buy-now", false
    assert_select ".market-listing__leader", /Leading:/
    assert_select ".market-listing__fact dt", text: "Leading", count: 0
    assert_select ".market-listing__price[aria-label='8,000 PiCoins']"
    assert_no_match(/8,500|8500/, response.body)
  end

  test "a private seller shows as a bare name, a banned one as the anonymous key" do
    @seller.update_columns(visibility: "private")
    sign_in(accounts_players(:moderator).tap { it.update_columns(role: "player") })
    annonce
    assert_select ".market-listing__fact span.player-name", "Alice"
    assert_select ".market-listing__fact a", false

    @seller.update_columns(banned_at: Time.current)
    annonce
    assert_select ".market-listing__fact .player-name--anonymous", "An anonymous player"
  end

  test "a player sees the balance chip" do
    sign_in(accounts_players(:administrator))
    annonce

    assert_select ".balance-chip"
  end

  test "a sold listing shows the same read-only facts" do
    @listing.update_columns(status: "sold", sold_at: Time.current, final_price: 7_800)
    annonce

    assert_response :success
    assert_select "h1", "Blue Depths"
  end

  test "the history of a listing with no bid is its creation line" do
    annonce

    assert_select ".market-history__heading", "HISTORY"
    assert_select ".market-history__line", count: 1
    assert_select ".market-history__line--created", /Listed by Alice/
    assert_select "#annonce-bid .market-outcome", false
  end

  test "a visitor reads the bids newest first, the leader's mark and no raise line, and no maximum" do
    bidder = accounts_players(:moderator)
    bidder.update_columns(persona_name: "Bob")
    Game::Market::Bid.create!(listing: @listing, player: bidder, maximum: 98_765, price_after: 7_800, outcome: "leading")
    Game::Market::Bid.create!(listing: @listing, player: bidder, maximum: 87_654, price_after: 7_800, outcome: "raise")
    @listing.update_columns(leader_id: bidder.id, leader_maximum: 87_654)
    annonce

    assert_select ".market-history__line", count: 2
    assert_select ".market-history__line--bid .market-history__leading", "Leading"
    assert_select ".market-history__line--raise", false
    assert_no_match(/98,765|98765|87,654|87654/, response.body)
    assert_select ".market-listing__leader", /Leading:\s*Bob/
  end

  test "the leader reads their raise line and still no amount of any maximum" do
    bidder = accounts_players(:moderator)
    Game::Market::Bid.create!(listing: @listing, player: bidder, maximum: 98_765, price_after: 7_800, outcome: "leading")
    Game::Market::Bid.create!(listing: @listing, player: bidder, maximum: 87_654, price_after: 7_800, outcome: "raise")
    @listing.update_columns(leader_id: bidder.id, leader_maximum: 87_654)
    sign_in(bidder)
    annonce

    assert_select ".market-history__line--raise", /raised their maximum/
    assert_no_match(/98,765|98765|87,654|87654/, response.body)
  end

  test "an open listing past its end reads closing where the form will sit" do
    @listing.update_columns(ends_at: 1.minute.ago)
    annonce

    assert_select "#annonce-bid .market-outcome--closing", "Closing…"
  end

  test "a sold listing reads the outcome for a visitor and keeps the history" do
    bidder = accounts_players(:moderator)
    Game::Market::Bid.create!(listing: @listing, player: bidder, maximum: 9_000, price_after: 7_800, outcome: "won")
    @listing.update_columns(status: "sold", sold_at: Time.current, final_price: 7_800, leader_id: bidder.id, leader_maximum: 9_000)
    annonce

    assert_select "#annonce-bid h2#listing-outcome-heading[tabindex='-1']", "AUCTION ENDED"
    assert_select "#annonce-bid .market-outcome__body", /wins Blue Depths for/
    assert_select "#annonce-bid .market-outcome__body .picoin-amount__figure", "7,800"
    assert_select ".market-history__line--bid", count: 1
    assert_no_match(/9,000|9000/, response.body)
  end

  test "the Annonce reads its history and outcome in French" do
    @listing.update_columns(status: "unsold")
    annonce(locale: :fr)

    assert_select ".market-history__heading", "HISTORIQUE"
    assert_select ".market-history__line--created", /Mise en vente par Alice/
    assert_select "#annonce-bid .market-outcome__title", "ENCHÈRE TERMINÉE"
    assert_select "#annonce-bid .market-outcome__body", "Aucune offre."
  end

  test "a visitor reads the sign-in line and no form" do
    annonce

    assert_select "#annonce-bid form", false
    assert_select "#annonce-bid a[href*='/sign-in']", "Sign in to bid"
    assert_select "section#annonce[data-controller=annonce]"
    assert_select "p[role=status][aria-live=polite][data-controller=annonce-status]", 1
  end

  test "a signed-in non-seller reads the form with its minimum, its sentences and no maximum typed" do
    sign_in(accounts_players(:administrator))
    annonce

    assert_select "#annonce-bid form#annonce-form[action=?]", market_listing_bids_path(locale: :en, token: @listing.token)
    assert_select "label[for=annonce-maximum]", "MY MAXIMUM"
    assert_select "input#annonce-maximum[type=text][inputmode=numeric][autocomplete=off][value='']"
    assert_select "#annonce-minimum", /At least\s*7,800/
    assert_select "input[name=drawn_minimum][value='7800']"
    assert_select ".market-bid__fixed", /the most you accept to pay/
    assert_select ".market-bid__small", /A bid cannot be cancelled/
    assert_select "[data-annonce-field-minimum-value='7800'][data-annonce-field-own-maximum-value='0'][data-annonce-field-buy-now-value='30000']"
    assert_select "[style]", false
  end

  test "the form carries the price and the unusual multiple of the current settings, and the dialogs and buy-now button" do
    Game::Market::Mint.credit(player_id: accounts_players(:administrator).id, amount: 50_000, settings_id: Game::Market::CurrentSettings.call.id)
    sign_in(accounts_players(:administrator))
    annonce

    multiple = Game::Market::CurrentSettings.call.unusual_maximum_multiple
    assert_select "[data-annonce-field-price-value='7800'][data-annonce-field-unusual-multiple-value='#{multiple}']"
    assert_select "dialog#annonce-unusual[data-controller~=annonce-dialog][data-annonce-dialog-kind-value=unusual] h2[tabindex='-1'][autofocus]", "UNUSUAL AMOUNT"
    assert_select "dialog#annonce-buy-now[data-annonce-dialog-kind-value=buy_now] h2[autofocus]", "BUY NOW"
    assert_select "dialog#annonce-buy-now #annonce-buy-now-text", /Blue Depths, rare/
    assert_select "dialog#annonce-buy-now button", /BUY · 30,000/
    assert_select "button[type=submit][name=buy_now][value='1']:not([disabled])", "BUY NOW"
  end

  test "the unusual multiple of the shared fixture is the settings value" do
    rows = JSON.parse(Rails.root.join("test/fixtures/files/unusual_maximums.json").read)

    assert_includes rows.map { it["multiple"] }, Game::Market::StartingSettings::ATTRIBUTES.fetch(:unusual_maximum_multiple)
  end

  test "the buy-now button is disabled with the available amount beside it when the hold is not covered" do
    sign_in(accounts_players(:administrator))
    annonce

    assert_select ".market-bid__buy-now button[disabled]", "BUY NOW"
    assert_select ".market-bid__buy-now .market-bid__small", /Available:/
  end

  test "a listing without a buy-now has no buy-now button and no buy-now dialog" do
    @listing.update_columns(buy_now_price: nil)
    sign_in(accounts_players(:administrator))
    annonce

    assert_select ".market-bid__buy-now", false
    assert_select "dialog#annonce-buy-now", false
    assert_select "dialog#annonce-unusual"
  end

  test "the seller and a visitor read neither button nor dialog" do
    annonce
    assert_select "dialog", false
    assert_select ".market-bid__buy-now", false

    sign_in(@seller)
    annonce
    assert_select "dialog", false
  end

  test "the seller reads no form" do
    sign_in(@seller)
    annonce

    assert_select "#annonce-bid form", false
    assert_select "#annonce-bid a", false
  end

  test "a leader reads the raising form built from their own maximum, and nobody else does" do
    bidder = accounts_players(:moderator)
    @listing.update_columns(leader_id: bidder.id, leader_maximum: 12_345, current_price: 8_000)
    sign_in(bidder)
    annonce

    assert_select "#annonce-minimum", /More than your current maximum,\s*12,345/
    assert_select "[data-annonce-field-minimum-value='12346'][data-annonce-field-own-maximum-value='12345']"

    sign_in(accounts_players(:administrator))
    annonce
    assert_no_match(/12,345|12345|12346/, response.body)
    assert_select "#annonce-minimum", /At least\s*8,400/
  end

  test "a closed listing draws no form" do
    sign_in(accounts_players(:administrator))
    @listing.update_columns(status: "unsold")
    annonce

    assert_select "#annonce-bid form", false
    assert_select "#annonce-bid .market-outcome"
  end

  test "an unknown token is a 404" do
    get market_listing_path(locale: :en, token: "A" * 24)

    assert_response :not_found
  end

  test "a GET writes nothing, the markup carries the token and never a database id or a style attribute" do
    assert_no_difference [ -> { Game::Market::Listing.count }, -> { Game::Market::LedgerEntry.count } ] do
      annonce
    end
    assert_select "[style]", false
    assert_no_match(/(?:id|listing)[-_=:"]#{@listing.id}\b/, response.body)
    assert_equal "/en/market/listings/#{@listing.token}", market_listing_path(locale: :en, token: @listing.token)
  end
end
