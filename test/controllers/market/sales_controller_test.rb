require "test_helper"
require_relative "../../support/steam_sign_in"
require_relative "../../support/holdings"
require_relative "../../support/market"
require_relative "../../support/counting_rate_limit"
require_relative "../../support/singleton_stub"

class Market::SalesControllerTest < ActionDispatch::IntegrationTest
  include SteamSignIn
  include Holdings
  include MarketSettings
  include CountingRateLimit
  include SingletonStub

  setup do
    @player = accounts_players(:player)
    @common = catalog_card_seasons(:common_card_one)
    @rare = catalog_card_seasons(:rare_card_one)
    Game::Market::Settings.delete_all
    @settings = open_market!
    fund(500)
  end

  def fund(amount) = Game::Market::Mint.credit(player_id: @player.id, amount:, settings_id: @settings.id)

  def ref(card_season) = "#{card_season.card.slug}:#{card_season.season.number}"

  def post_sale(card_season = @common, **overrides)
    post market_sales_path(locale: :en), params: { settings: @settings.token, ref: ref(card_season), starting_price: "1300",
      duration_hours: "24", **overrides }
  end

  def nothing_moves(&)
    assert_no_difference([ -> { Game::Market::Listing.count }, -> { Game::Market::LedgerEntry.count }, -> { Game::Holding.sum(:reserved) } ], &)
  end

  test "the page draws one cell per edition with a free copy, and a GET writes nothing" do
    hold(@player, @rare.id, 3, reserved: 1)
    hold(@player, @common.id, 1)
    hold(@player, catalog_card_seasons(:uncommon_card_one).id, 1, reserved: 1)
    sign_in(@player)

    assert_no_difference [ -> { Game::Holding.sum(:quantity) }, -> { Game::Market::LedgerEntry.count }, -> { Game::Market::Wallet.count } ] do
      get new_market_sale_path(locale: :en)
    end

    assert_response :success
    assert_select "input[name=settings][value=?]", @settings.token
    assert_select "form#listing-form[data-controller=listing-form][data-layout=wide][data-chosen=false]"
    assert_select "[role=listbox] [role=option]", 2
    assert_select "[role=option]:first-child[data-ref=?][data-free=2][data-minimum=7800][data-stamp=2000][aria-selected=false][tabindex='0']", ref(@rare)
    assert_select "[role=option]:last-child[data-ref=?][data-free=1][tabindex='-1']", ref(@common)
    assert_select "[role=option]:first-child .sale-cell__minimum .picoin-amount__figure", "7,800"
    assert_select "[role=option]:first-child .card"
    assert_select ".sale-fields[inert]"
    assert_select "input[name=ref][value='']"
    assert_select "[style]", false
  end

  test "the form carries its fields, the three durations with the preselected one, the lines and the button" do
    hold(@player, @common.id, 1)
    sign_in(@player)

    get new_market_sale_path(locale: :en)

    assert_select "input[name=starting_price][inputmode=numeric][autocomplete=off][type=text]"
    assert_select "input[name=buy_now_price]", false
    assert_select "input[name=duration_hours]", 3
    assert_select "input[name=duration_hours][value=24][checked]"
    assert_select ".sale-durations__choice", text: /12 H/
    assert_select ".sale-durations__choice", text: /3 DAYS/
    assert_select ".sale-line", 3
    assert_select ".sale-line", text: /10% of the final price, at the sale/
    assert_select "button[type=submit][aria-describedby=sale-rules]", text: /PUT UP FOR SALE/
    assert_select "[role=status][aria-live=polite]"
    assert_select "form[data-turbo=false]"
  end

  test "a card's page lists only that card's editions and preselects the only one" do
    hold(@player, @rare.id, 2)
    hold(@player, @common.id, 1)
    sign_in(@player)

    get new_market_card_sale_path(locale: :en, slug: @rare.card.slug)

    assert_select "[role=option]", 1
    assert_select "[role=option][aria-selected=true][data-ref=?]", ref(@rare)
    assert_select "input[name=ref][value=?]", ref(@rare)
    assert_select "form#listing-form[data-chosen=true][data-step='2']"
    assert_select "input[name=card][value=?]", @rare.card.slug
    assert_select ".sale-fields[inert]", false
    assert_select "#sale-start-hint", "At least 7,800 for a rare"
  end

  test "an unknown card slug is not found" do
    sign_in(@player)

    get new_market_card_sale_path(locale: :en, slug: "no-such-card")

    assert_response :not_found
  end

  test "a prefill chooses the edition, fills the amounts and says they are the previous sale's" do
    hold(@player, @rare.id, 2)
    hold(@player, @common.id, 1)
    sign_in(@player)

    get new_market_sale_path(locale: :en, ref: ref(@common), start: "1500", relisting: "1")

    assert_select "[role=option][aria-selected=true][data-ref=?]", ref(@common)
    assert_select "input[name=starting_price][value='1,500']"
    assert_select ".market-sale__relisting", "These amounts are those of your previous sale."
  end

  test "an unknown ref and non-digit amounts in a prefill are ignored" do
    hold(@player, @rare.id, 2)
    hold(@player, @common.id, 1)
    sign_in(@player)

    get new_market_sale_path(locale: :en, ref: "nothing:1", start: "1500", relisting: "1")
    assert_select "[role=option][aria-selected=true]", false
    assert_select "input[name=starting_price][value='']"
    assert_select ".market-sale__relisting", false

    get new_market_sale_path(locale: :en, ref: ref(@common), start: "12x")
    assert_select "[role=option][aria-selected=true][data-ref=?]", ref(@common)
    assert_select "input[name=starting_price][value='']"
  end

  test "with nothing free to list the page says so and points to the capsules" do
    hold(@player, @common.id, 1, reserved: 1)
    sign_in(@player)

    get new_market_sale_path(locale: :fr)

    assert_response :success
    assert_select ".market-sale__notice", /Aucune carte disponible à la vente\./
    assert_select ".market-sale__notice a[href=?]", booster_path(locale: :fr), "OUVRIR UNE CAPSULE"
    assert_select "form#listing-form", false
  end

  test "a visitor reads a sign-in panel with no form" do
    hold(@player, @common.id, 1)

    get new_market_sale_path(locale: :en)

    assert_response :success
    assert_select ".market-sale__notice a[href=?]", sign_in_path(locale: :en)
    assert_select "form#listing-form", false
    assert_select ".balance-chip", false
  end

  test "while the first closed version exists the form is not shown to a player with nothing to sell and the closed panel reads" do
    forget_market!
    Game::Market::CreateFirstSettings.new.call.value!
    hold(@player, @common.id, 1)
    sign_in(@player)

    get new_market_sale_path(locale: :en)

    assert_response :success
    assert_select ".market-sale__notice", /closed/
    assert_select "button[disabled]"
  end

  test "a suspended market shows the banner and a disabled button with a link back to the market" do
    close_market!(first_opened_at: 2.days.ago)
    hold(@player, @common.id, 1)
    sign_in(@player)

    get new_market_sale_path(locale: :en)

    assert_select "#market-suspended-banner a[href=?]", market_path(locale: :en)
    assert_select "button[disabled]"
  end

  test "no database id is in the markup" do
    hold(@player, @rare.id, 1)
    sign_in(@player)

    get new_market_sale_path(locale: :en)

    assert_no_match(/(?:data-[a-z-]+|id|name|value)="#{@rare.id}"/, response.body)
  end

  test "the page reads in French" do
    hold(@player, @common.id, 1)
    sign_in(@player)

    get new_market_sale_path(locale: :fr)

    assert_select "h1", "Mettre en vente"
    assert_select "label", text: /PRIX DE DÉPART/
    assert_select ".sale-line", text: /Timbre Fiscal du Gamebler/
    assert_select ".sale-line", text: /Vendue au prix de départ, vous recevez/
    assert_select ".sale-durations__choice", text: /3 JOURS/
    assert_select ".sale-cell__free", "1 disponible"
  end

  test "a valid post lists the card, stamps the player, reserves the copy and lands on the Annonce" do
    hold(@player, @common.id, 2)
    sign_in(@player)

    assert_difference -> { Game::Market::Listing.count }, 1 do
      assert_difference -> { Game::Market::LedgerEntry.where(kind: "stamp").count }, 1 do
        post_sale(starting_price: "1500", duration_hours: "72")
      end
    end

    listing = Game::Market::Listing.order(:id).last
    assert_redirected_to market_listing_path(locale: :en, token: listing.token)
    assert_response :see_other
    assert_equal [ 1_500, 72 ], [ listing.starting_price, listing.duration_hours ]
    assert_equal 1, Game::Holding.find_by!(player_id: @player.id, card_season_id: @common.id).reserved
    assert_equal 400, Game::Market::Balance.call(@player).available
  end

  test "a start under the minimum is refused under the field with the minimum, the typed amounts kept and nothing charged" do
    hold(@player, @common.id, 1)
    sign_in(@player)

    nothing_moves { post_sale(starting_price: "1000", duration_hours: "72") }

    assert_response :unprocessable_content
    assert_select "#sale-start-error", "At least 1,300 for a common."
    assert_select "input[name=starting_price][value='1,000'][aria-invalid=true]"
    assert_select "input[name=starting_price][aria-describedby=?]", "sale-start-hint sale-start-error"
    assert_select "input[name=duration_hours][value=72][checked]"
    assert_select "[role=option][aria-selected=true][data-ref=?]", ref(@common)
    assert_equal 500, Game::Market::Balance.call(@player).available
  end

  test "a short stamp names the shortfall, not the stamp, and links to Confier" do
    Game::Market::Wallet.where(player_id: @player.id).update_all(available: 120)
    hold(@player, @rare.id, 1)
    sign_in(@player)

    nothing_moves { post_sale(@rare, starting_price: "7800") }

    assert_response :unprocessable_content
    assert_select ".sale-summary .sale-summary__short[role=alert]:not([hidden])", text: /You are short of 1,880 PiCoins for the stamp\./
    assert_select ".sale-summary .sale-summary__short a[href=?]", new_market_entrustment_path(locale: :en), "ENTRUST CARDS"
    assert_select "input[name=starting_price][value='7,800']"
  end

  test "a stamp the balance cannot pay shows in red with its shortfall before any post, the button described by it" do
    Game::Market::Wallet.where(player_id: @player.id).update_all(available: 120)
    hold(@player, @rare.id, 1)
    sign_in(@player)

    get new_market_card_sale_path(locale: :en, slug: @rare.card.slug)

    assert_select ".sale-line--short[data-listing-summary-target=stampLine]"
    assert_select ".sale-summary__short:not([role]):not([hidden]) [data-listing-summary-target=shortText]", "You are short of 1,880 PiCoins for the stamp."
    assert_select ".sale-summary__submit button[type=submit][aria-describedby=?]", "sale-short sale-rules"
    assert_select "form[data-listing-form-available-value='120']"
  end

  test "an amount that is not a price is refused 422 under its field, with the values kept" do
    hold(@player, @common.id, 1)
    sign_in(@player)

    [ "", "0", "12x", "1.5" ].each do |start|
      nothing_moves { post_sale(starting_price: start, duration_hours: "72") }

      assert_response :unprocessable_content
      assert_select "#sale-start-error", "Enter a whole number of PiCoins, above zero."
      assert_select "input[name=starting_price][aria-invalid=true]"
      assert_select "input[name=duration_hours][value=72][checked]"
    end
  end

  test "a start grouped by thousands lists the card at that amount" do
    hold(@player, @common.id, 3)
    sign_in(@player)

    [ "8,000", "8 000", "8\u00A0000" ].each { post_sale(starting_price: it, duration_hours: "72") }

    assert_equal [ 8_000 ] * 3, Game::Market::Listing.order(:id).last(3).map(&:starting_price)
  end

  test "a start grouped wrongly is refused like any other non-price, and comes back as typed" do
    hold(@player, @common.id, 1)
    sign_in(@player)

    [ "12,5", "1,0000", "1,000 000" ].each do |start|
      nothing_moves { post_sale(starting_price: start, duration_hours: "72") }

      assert_response :unprocessable_content
      assert_select "#sale-start-error", "Enter a whole number of PiCoins, above zero."
      assert_select "input[name=starting_price][value=?]", start
    end
  end

  test "a duration outside the three is refused under the duration group with no duration checked" do
    hold(@player, @common.id, 1)
    sign_in(@player)

    nothing_moves { post_sale(starting_price: "1500", duration_hours: "5") }

    assert_response :unprocessable_content
    assert_select "fieldset[aria-describedby=sale-duration-error][aria-invalid=true]"
    assert_select "#sale-duration-error", "Choose one of the listed durations."
    assert_select "input[name=duration_hours][checked]", false
    assert_select "input[name=starting_price][value='1,500']"
  end

  test "a copy that is gone is refused above the grid and drops out of it" do
    hold(@player, @common.id, 1, reserved: 1)
    hold(@player, @rare.id, 1)
    sign_in(@player)

    nothing_moves { post_sale(@common) }

    assert_response :unprocessable_content
    assert_select ".sale-grid .market-sale__refusal", "This card is no longer available."
    assert_select "[role=option][data-ref=?]", ref(@common), false
    assert_select "[role=option][data-ref=?]", ref(@rare)
  end

  test "an unknown ref is a copy that is gone" do
    hold(@player, @common.id, 1)
    sign_in(@player)

    nothing_moves { post_sale(ref: "nothing:1") }

    assert_response :unprocessable_content
    assert_select ".sale-grid .market-sale__refusal", "This card is no longer available."
  end

  test "an edition with no rarity is refused above the grid and left out of it" do
    hold(@player, @common.id, 1)
    hold(@player, @rare.id, 1)
    sign_in(@player)
    @common.update_columns(rarity: nil)

    nothing_moves { post_sale(@common) }

    assert_response :unprocessable_content
    assert_select ".sale-grid .market-sale__refusal", text: /no rarity yet/
    assert_select "[role=option][data-ref=?]", ref(@common), false
  end

  test "a stale version redraws the new amounts and keeps what was typed, charging nothing" do
    hold(@player, @common.id, 1)
    sign_in(@player)
    stale = @settings.token
    @settings = open_market!(minimum_price_common: 1_500)

    nothing_moves { post market_sales_path(locale: :en), params: { settings: stale, ref: ref(@common), starting_price: "1400", duration_hours: "72" } }

    assert_response :unprocessable_content
    assert_select ".sale-summary .market-sale__refusal", text: /amounts changed/
    assert_select "input[name=settings][value=?]", @settings.token
    assert_select "[role=option][data-minimum=1500]"
    assert_select "input[name=starting_price][value='1,400']"
    assert_select "input[name=duration_hours][value=72][checked]"
    assert_equal 500, Game::Market::Balance.call(@player).available
  end

  test "a busy market keeps what was typed" do
    hold(@player, @common.id, 1)
    sign_in(@player)

    stub_singleton(Game::Market::Ledger, :post, ->(_entries) { raise ActiveRecord::Deadlocked }) do
      nothing_moves { post_sale(starting_price: "1700") }
    end

    assert_response :unprocessable_content
    assert_select ".sale-summary .market-sale__refusal", text: /The Archives are busy/
    assert_select "input[name=starting_price][value='1,700']"
  end

  test "a closed market refuses the post and draws the closed panel" do
    hold(@player, @common.id, 1)
    sign_in(@player)
    @settings = close_market!(first_opened_at: 2.days.ago)

    nothing_moves { post_sale }

    assert_response :unprocessable_content
    assert_select "#market-suspended-banner a[href=?]", market_path(locale: :en)
    assert_select ".market-sale__refusal", false
  end

  test "a visitor's post is refused with sign_in_required and writes nothing" do
    hold(@player, @common.id, 1)

    nothing_moves { post_sale }
    assert_response :see_other

    nothing_moves { post market_sales_path(locale: :en, format: :json), params: { settings: @settings.token, ref: ref(@common), starting_price: "1300", duration_hours: "24" } }
    assert_response :unauthorized
    assert_equal "sign_in_required", response.parsed_body.dig("error", "code")
  end

  test "the eleventh post of a minute is throttled" do
    sign_in(@player)

    with_counting_rate_limit(Market::SalesController) { 11.times { post_sale } }

    assert_redirected_to new_market_sale_path(locale: :en)
  end

  test "the card-scoped address and a prefilled relist draw the banner with its link back while suspended" do
    close_market!(first_opened_at: 2.days.ago)
    hold(@player, @common.id, 1)
    sign_in(@player)

    get new_market_card_sale_path(locale: :en, slug: @common.card.slug)
    assert_response :success
    assert_select "#market-suspended-banner a[href=?]", market_path(locale: :en)
    assert_select "button[disabled]"

    get new_market_sale_path(locale: :en, ref: ref(@common), start: "2000", relisting: 1)
    assert_response :success
    assert_select "#market-suspended-banner a[href=?]", market_path(locale: :en)
    assert_select "button[disabled]"
    assert_select ".market-sale__relisting"
  end

  def after_the_first_opening
    forget_market!
    @settings = open_market!(first_opened_at: 1.day.ago)
    fund(500)
  end

  test "after the first opening each cell carries its edition's price and its words, and a template per edition feeds the form" do
    after_the_first_opening
    Game::Market::EditionPrice.create!(card_season_id: @rare.id, average: 15_000, sales_used: 5)
    Game::Market::EditionPrice.create!(card_season_id: @common.id, average: 800, sales_used: 2)
    hold(@player, @rare.id, 1)
    hold(@player, @common.id, 1)
    sign_in(@player)

    get new_market_sale_path(locale: :en)

    assert_select "[role=option][data-ref=?] .sale-cell__price .picoin-amount[aria-label='15,000 PiCoins']", ref(@rare)
    assert_select "[role=option][data-ref=?] .sale-cell__price .average-price__few", ref(@common), "few sales"
    assert_select "[role=option][data-ref=?][aria-label$=?]", ref(@rare), "average price 15,000 PiCoins"
    assert_select "template[data-listing-fields-target=priceTemplate]", 2
    assert_select "template[data-ref=?]", ref(@rare)
    assert_select ".sale-price[data-listing-fields-target=priceSlot][data-ref='']"
    assert_select ".sale-price .average-price", false
  end

  test "an edition without any sale says so, in the cell and the form" do
    after_the_first_opening
    hold(@player, @common.id, 1)
    sign_in(@player)

    get new_market_sale_path(locale: :en)

    assert_select "[role=option] .sale-cell__price .average-price--none", "No sale"
    assert_select ".sale-price[data-ref=?] .average-price--none", ref(@common)
    assert_select ".sale-price .sale-field__label", "Average price"
  end

  test "a single free edition opens chosen with its price already in the form, with its sale count" do
    after_the_first_opening
    Game::Market::EditionPrice.create!(card_season_id: @rare.id, average: 15_000, sales_used: 5)
    hold(@player, @rare.id, 1)
    sign_in(@player)

    get new_market_sale_path(locale: :en)

    assert_select ".sale-price[data-ref=?] .picoin-amount[aria-label='15,000 PiCoins']", ref(@rare)
    assert_select ".sale-price .average-price__basis", "Based on 5 sales"
  end

  test "a refused post keeps the chosen edition's price in the form" do
    after_the_first_opening
    Game::Market::EditionPrice.create!(card_season_id: @rare.id, average: 15_000, sales_used: 5)
    hold(@player, @rare.id, 1)
    hold(@player, @common.id, 1)
    sign_in(@player)

    post_sale(@rare, starting_price: "10")

    assert_response :unprocessable_content
    assert_select ".sale-price[data-ref=?] .picoin-amount[aria-label='15,000 PiCoins']", ref(@rare)
  end

  test "no price, slot or template shows before the market's first opening" do
    Game::Market::EditionPrice.create!(card_season_id: @rare.id, average: 15_000, sales_used: 5)
    hold(@player, @rare.id, 1)
    sign_in(@player)

    get new_market_sale_path(locale: :en)

    assert_select ".sale-cell__price", false
    assert_select ".sale-price", false
    assert_select "template[data-listing-fields-target=priceTemplate]", false
    assert_select "[role=option][aria-label*=average]", false
  end
end
