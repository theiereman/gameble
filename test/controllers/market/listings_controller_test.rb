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
    @listing = listing!(seller: @seller, card_season: catalog_card_seasons(:rare_card_one), starting_price: 7_800,
      ends_at: (2.hours + 14.minutes + 30.seconds).from_now)
  end

  def annonce(locale: :en) = get(market_listing_path(locale:, token: @listing.token))

  test "a visitor reads the Annonce: card, seller, price and time left with the end time" do
    annonce

    assert_response :success
    assert_select "h1#market-listing-heading[tabindex='-1'][autofocus]", "Blue Depths"
    assert_select ".market-listing__price .picoin-amount__figure", "7,800"
    assert_select ".market-listing__price[aria-label='7,800 PiCoins']"
    assert_select ".market-listing__time", "2 h 14"
    assert_select ".market-listing__time--soon", false
    assert_select ".market-listing__ends time[datetime]"
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

  test "a leader is shown without their maximum" do
    @listing.update_columns(leader_id: accounts_players(:moderator).id, leader_maximum: 8_500, current_price: 8_000)
    annonce

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
    @listing.update_columns(status: "sold", sold_at: Time.current, final_price: 7_800, leader_id: accounts_players(:moderator).id, leader_maximum: 7_800)
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
    Game::Market::Bid.create!(listing: @listing, player: bidder, maximum: 19_876, price_after: 7_800, outcome: "leading")
    Game::Market::Bid.create!(listing: @listing, player: bidder, maximum: 18_765, price_after: 7_800, outcome: "raise")
    @listing.update_columns(leader_id: bidder.id, leader_maximum: 18_765)
    annonce

    assert_select ".market-history__line", count: 2
    assert_select ".market-history__line--bid .market-history__leading", "Leading"
    assert_select ".market-history__line--raise", false
    assert_no_match(/19,876|19876/, response.body)
    assert_select ".market-listing__leader", /Leading:\s*Bob/
  end

  test "the leader reads their raise line and never the maximum it replaced" do
    bidder = accounts_players(:moderator)
    Game::Market::Bid.create!(listing: @listing, player: bidder, maximum: 19_876, price_after: 7_800, outcome: "leading")
    Game::Market::Bid.create!(listing: @listing, player: bidder, maximum: 18_765, price_after: 7_800, outcome: "raise")
    @listing.update_columns(leader_id: bidder.id, leader_maximum: 18_765)
    sign_in(bidder)
    annonce

    assert_select ".market-history__line--raise", /raised their maximum/
    assert_no_match(/19,876|19876/, response.body)
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
    assert_select "section#annonce[data-controller~=annonce]"
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
    assert_select "[data-annonce-field-minimum-value='7800'][data-annonce-field-own-maximum-value='0']"
    assert_select "[style]", false
  end

  test "the form carries the price and the unusual multiple of the current settings, and the unusual dialog only" do
    Game::Market::Mint.credit(player_id: accounts_players(:administrator).id, amount: 50_000, settings_id: Game::Market::CurrentSettings.call.id)
    sign_in(accounts_players(:administrator))
    annonce

    multiple = Game::Market::CurrentSettings.call.unusual_maximum_multiple
    assert_select "[data-annonce-field-price-value='7800'][data-annonce-field-unusual-multiple-value='#{multiple}']"
    assert_select "dialog#annonce-unusual[data-controller~=annonce-dialog][data-annonce-dialog-kind-value=unusual] h2[tabindex='-1'][autofocus]", "UNUSUAL AMOUNT"
    assert_select "dialog[data-annonce-dialog-kind-value]", 1
    assert_select "button[name=buy_now]", false
  end

  test "quick amounts fill the minimum or a raise above it" do
    Game::Market::Mint.credit(player_id: accounts_players(:administrator).id, amount: 50_000, settings_id: Game::Market::CurrentSettings.call.id)
    sign_in(accounts_players(:administrator))
    annonce

    assert_select ".market-bid__shortcut[data-action='annonce-field#fill']", 3
    assert_select ".market-bid__shortcut[data-annonce-field-amount-param='7800']", "MINIMUM · 7,800"
    assert_select ".market-bid__shortcut[data-annonce-field-amount-param='8600']", "+10% · 8,600"
    assert_select ".market-bid__shortcut[data-annonce-field-amount-param='9800']", "+25% · 9,800"
  end

  test "the Annonce carries its rarity and season above the title and a gauge of the time gone" do
    annonce

    assert_select ".market-listing__kicker--rare", /RARE · SEASON/i
    assert_select "progress.market-listing__progress[max][value]"
    assert_select ".market-listing__progress--soon", false
  end

  test "the unusual multiple of the shared fixture is the settings value" do
    rows = JSON.parse(Rails.root.join("test/fixtures/files/unusual_maximums.json").read)

    assert_includes rows.map { it["multiple"] }, Game::Market::StartingSettings::ATTRIBUTES.fetch(:unusual_maximum_multiple)
  end

  test "the seller and a visitor read no bid dialog" do
    annonce
    assert_select "dialog", false

    sign_in(@seller)
    annonce
    assert_select "dialog#annonce-unusual", false
  end

  test "the seller reads no form" do
    sign_in(@seller)
    annonce

    assert_select "#annonce-bid form#annonce-form", false
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

  def cancel_dialog = css_select("#annonce-bid dialog#cancel-#{@listing.token}")

  test "the seller of an open listing without a leader reads ANNULER and its dialog back to the Annonce" do
    sign_in(@seller)
    annonce

    assert_select "#annonce-bid button[aria-label=?]", "Cancel the sale, Blue Depths", "CANCEL"
    assert_equal 1, cancel_dialog.size
    assert_select "dialog#cancel-#{@listing.token} input[name=return_to][value=annonce]"
    assert_select "dialog#cancel-#{@listing.token} form[action=?]", market_listing_cancellation_path(locale: :en, token: @listing.token)
  end

  test "no ANNULER with a leader, once ended or due, for another player or for a visitor" do
    sign_in(@seller)
    @listing.update_columns(leader_id: accounts_players(:moderator).id, leader_maximum: 9_000)
    annonce
    assert_empty cancel_dialog

    @listing.update_columns(leader_id: nil, leader_maximum: nil, ends_at: 1.minute.ago)
    annonce
    assert_empty cancel_dialog

    @listing.update_columns(ends_at: 1.hour.from_now, status: "unsold")
    annonce
    assert_empty cancel_dialog

    @listing.update_columns(status: "open")
    sign_in(accounts_players(:administrator))
    annonce
    assert_empty cancel_dialog
  end

  test "a visitor reads no ANNULER" do
    annonce

    assert_empty cancel_dialog
    assert_select "button", text: "CANCEL", count: 0
  end

  test "focus=maximum writes the field focus target for a bidder, and nothing for any other viewer or value" do
    sign_in(accounts_players(:administrator))
    get market_listing_path(locale: :en, token: @listing.token, focus: "maximum")
    assert_select "#annonce-bid[data-focus=field]"
    assert_select "#annonce-bid [data-focus-name=field]"

    get market_listing_path(locale: :en, token: @listing.token, focus: "heading")
    assert_select "#annonce-bid[data-focus]", false

    get market_listing_path(locale: :en, token: @listing.token)
    assert_select "#annonce-bid[data-focus]", false
  end

  test "focus=maximum changes nothing for the seller or a visitor" do
    get market_listing_path(locale: :en, token: @listing.token, focus: "maximum")
    assert_select "[data-focus]", false

    sign_in(@seller)
    get market_listing_path(locale: :en, token: @listing.token, focus: "maximum")
    assert_select "[data-focus]", false
  end

  def close_after_opening = close_market!(first_opened_at: 1.day.ago)

  test "a suspended Annonce draws the banner in its slot and a disabled form for a bidder, with no script" do
    close_after_opening
    sign_in(accounts_players(:administrator))
    annonce

    assert_select "#annonce-suspension #market-suspended-banner", 1
    assert_select "#annonce-bid input#annonce-maximum[disabled][aria-describedby~=market-suspended-banner]"
    assert_select "#annonce-bid button[disabled][aria-describedby=market-suspended-banner]", text: "BID"
    assert_select "#annonce-bid dialog", false
    assert_select "#annonce-bid [data-controller~=annonce-field]", false
    assert_select "#annonce-bid [data-controller~=annonce-foot]", false
    assert_select ".market-listing__price .picoin-amount__figure", "7,800"
    assert_select ".market-listing__time"
    assert_select ".market-history"
  end

  test "a suspended Annonce shows the leader's raise disabled and their own maximum" do
    bidder = accounts_players(:moderator)
    @listing.update_columns(leader_id: bidder.id, leader_maximum: 12_345, current_price: 8_000)
    close_after_opening
    sign_in(bidder)
    annonce

    assert_select "#annonce-bid button[disabled]", text: "RAISE"
    assert_select "#annonce-minimum", /12,345/
  end

  test "a suspended Annonce keeps the seller's ANNULER, the visitor's sign-in line and an ended listing's outcome" do
    close_after_opening
    sign_in(@seller)
    annonce
    assert_select "#market-suspended-banner", 1
    assert_select "#annonce-bid button[aria-label=?]:not([disabled])", "Cancel the sale, Blue Depths"
    assert_select "#annonce-bid form#annonce-form", false

    reset!
    annonce
    assert_select "#market-suspended-banner", 1
    assert_select ".market-bid__sign-in a"

    @listing.update_columns(status: "unsold")
    annonce
    assert_select "#annonce-bid .market-outcome"
  end

  test "an outbid player reads the outbid panel above the field, and no one else does" do
    rival = accounts_players(:moderator)
    rival.update_columns(persona_name: "Bob")
    reader = accounts_players(:administrator)
    @listing.update_columns(leader_id: rival.id, leader_maximum: 9_000, current_price: 8_000)
    Game::Market::Notice.record(player_id: reader.id, listing_id: @listing.id, kind: "outbid", other_player_id: rival.id, amount: 7_800)
    sign_in(reader)
    annonce

    assert_select "#annonce-bid #annonce-outbid.market-event--outbid h2", "YOU WERE OUTBID"
    assert_select "#annonce-outbid .market-event__body", /Bob moved ahead on Blue Depths\. Your 7,800 are available again\./
    assert_select "#annonce-outbid a.button--link[href=?]", market_listing_path(locale: :en, token: @listing.token, focus: "maximum")
    assert_select "#annonce-outbid ~ form#annonce-form"
    assert_select "#annonce-outbid [autofocus], #annonce-outbid [data-focus-name]", false

    reset!
    sign_in(rival)
    annonce
    assert_select "#annonce-outbid", false
  end

  test "an extended auction shows the extended panel to a visitor, and the page subscribes to the listing's stream and refreshes on it" do
    ends_at = 2.minutes.from_now.change(usec: 0)
    @listing.update_columns(ends_at:)
    Game::Market::Bid.create!(listing: @listing, player: accounts_players(:moderator), maximum: 9_000, price_after: 7_800, outcome: "leading", extended_until: ends_at)
    annonce

    assert_select "#annonce-bid #annonce-extended.market-event--extended h2", "AUCTION EXTENDED"
    assert_select "#annonce-extended time[datetime]"
    assert_select "#annonce-extended", /last 3 minutes/
    assert_select "#annonce[data-controller~=live-refresh][data-live-refresh-signal-value=listing-updated]"
    assert_select "turbo-cable-stream-source[channel='Turbo::StreamsChannel']", minimum: 1
    assert_no_match(/market-listing:/, response.body)
  end

  test "the page carries the status line for the polite region, in each language, and the not-recorded sentence as a template" do
    @listing.update_columns(leader_id: accounts_players(:moderator).id, leader_maximum: 9_000, current_price: 8_000)
    accounts_players(:moderator).update_columns(persona_name: "Bob")
    annonce

    assert_select "#annonce [data-status-text^='Price 8,000 PiCoins, leading Bob. Ends at ']"
    assert_select "#annonce [data-status-ends-at=?]", @listing.reload.ends_at.utc.iso8601
    assert_select "#annonce [data-status-bidder=false]"
    assert_select "#annonce template[data-annonce-target=notRecorded] .market-bid__note", "Your amount was not recorded."
    assert_select "#annonce[data-action*='listing-clock:ended->annonce#ended'][data-action*='turbo:morph@document->annonce#morphed']"

    annonce(locale: :fr)
    assert_select "#annonce [data-status-text^='Prix '][data-status-text*=', en tête Bob. Fin à ']"
  end

  test "the status line says you are leading to the leader and has none once an outcome shows" do
    leader = accounts_players(:moderator)
    @listing.update_columns(leader_id: leader.id, leader_maximum: 9_000, current_price: 8_000)
    sign_in(leader)
    annonce
    assert_select "#annonce [data-status-text*='you are leading']"

    @listing.update_columns(status: "unsold", leader_id: nil, leader_maximum: nil)
    annonce
    assert_select "#annonce [data-status-text]", false
  end

  test "an open market draws an empty slot and the live form" do
    sign_in(accounts_players(:administrator))
    annonce

    assert_select "#annonce-suspension"
    assert_select "#market-suspended-banner", false
    assert_select "#annonce-bid input#annonce-maximum[data-turbo-permanent]:not([disabled])"
  end

  test "the Annonce shows the edition's average price with its sale count, before the seller" do
    Game::Market::EditionPrice.create!(card_season_id: catalog_card_seasons(:rare_card_one).id, average: 15_000, sales_used: 5)

    annonce

    assert_select ".market-listing__fact--price dt", "Average price"
    assert_select ".market-listing__fact--price .picoin-amount[aria-label='15,000 PiCoins']"
    assert_select ".market-listing__fact--price .average-price__basis", "Based on 5 sales"
    assert_select ".market-listing__facts > .market-listing__fact:first-child.market-listing__fact--price"
  end

  test "an edition with few sales says so, one with none says No sale in French" do
    Game::Market::EditionPrice.create!(card_season_id: catalog_card_seasons(:rare_card_one).id, average: 9_000, sales_used: 2)

    annonce
    assert_select ".market-listing__fact--price .average-price__few", "few sales"
    assert_select ".market-listing__fact--price .average-price__basis", "Based on 2 sales"

    Game::Market::EditionPrice.delete_all
    annonce(locale: :fr)
    assert_select ".market-listing__fact--price dt", "Prix moyen"
    assert_select ".market-listing__fact--price .average-price--none", "Sans vente"
    assert_select ".market-listing__fact--price .average-price__basis", false
  end

  test "no average price shows before the market's first opening" do
    Game::Market::Settings.update_all(first_opened_at: nil)

    annonce

    assert_select ".market-listing__fact--price", false
  end
end
