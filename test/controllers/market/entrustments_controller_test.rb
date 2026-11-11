require "test_helper"
require_relative "../../support/steam_sign_in"
require_relative "../../support/holdings"
require_relative "../../support/market"
require_relative "../../support/counting_rate_limit"

class Market::EntrustmentsControllerTest < ActionDispatch::IntegrationTest
  include SteamSignIn
  include Holdings
  include MarketSettings
  include CountingRateLimit

  setup do
    @player = accounts_players(:player)
    @common = catalog_card_seasons(:common_card_one)
    @rare = catalog_card_seasons(:rare_card_one)
    Game::Market::Settings.delete_all
  end

  def ref(card_season) = "#{card_season.card.slug}:#{card_season.season.number}"

  test "the page lists the free copies with their value and the version drawn, and a GET writes nothing" do
    settings = open_market!
    hold(@player, @rare.id, 3, reserved: 1)
    hold(@player, @common.id, 1)
    sign_in(@player)

    assert_no_difference [ -> { Game::Holding.sum(:quantity) }, -> { Game::Market::LedgerEntry.count }, -> { Game::Market::Wallet.count } ] do
      get new_market_entrustment_path(locale: :en)
    end

    assert_response :success
    assert_select "input[name=settings][value=?]", settings.token
    assert_select "form#entrust[data-controller=entrust][data-entrust-cap-left-value=?][data-entrust-open-value=true]", "1200000"
    assert_select ".entrust-cell", 2
    assert_select ".entrust-cell:first-child .entrust-cell__value .picoin-amount[aria-label=?]", "5,000 PiCoins"
    assert_select ".entrust-cell:first-child .entrust-cell__value .picoin-amount__figure", "5,000"
    assert_select ".entrust-cell:first-child[data-ref=?][data-free=2][data-owned=3][data-value=5000][data-rarity=rare]", ref(@rare)
    assert_select ".entrust-cell:last-child[data-ref=?][data-free=1][data-owned=1]", ref(@common)
    assert_select "input[type=hidden][name=?][disabled]", "copies[#{ref(@rare)}]"
    assert_select "[style]", false
    assert_select "[name=?]", "copies[#{@rare.id}]", false
  end

  test "the page carries the wide layout, the bar, the sheet, one recap, one submit and two status lines" do
    open_market!
    hold(@player, @rare.id, 2)
    sign_in(@player)

    get new_market_entrustment_path(locale: :en)

    assert_select "form#entrust[data-layout=wide]"
    assert_select "form#entrust .market-entrust__layout[data-controller=entrust-recap]"
    assert_select ".entrust-bar[role=group] a[data-bottom-sheet-opens=entrust-recap-sheet]", "Entrust ▸"
    assert_select ".entrust-bar [data-entrust-recap-target=barTotal] .picoin-amount__figure", "0"
    assert_select "dialog#entrust-recap-sheet .modal__title", "Entrust"
    assert_select "dialog#entrust-recap-sheet [data-entrust-recap-target=sheetBody]"
    assert_select "form#entrust .market-entrust__slot > aside.entrust-recap", 1
    assert_select "button[type=submit]", 1
    assert_select "aside [data-entrust-recap-target=status][aria-live=polite]", 1
    assert_select "dialog [data-entrust-recap-target=barStatus]", false
    assert_select ".market-entrust__layout > [data-entrust-recap-target=barStatus][aria-live=polite]", 1
    assert_select "template[data-entrust-recap-target=stepperTemplate] .entrust-recap__stepper .stepper"
    assert_select "[data-action*='mousedown->entrust-recap#keepFocus']"
    assert_select "[style]", false
  end

  test "a cell with several free copies carries a stepper and an only copy does not" do
    open_market!
    hold(@player, @rare.id, 3)
    hold(@player, @common.id, 1)
    sign_in(@player)

    get new_market_entrustment_path(locale: :en)

    assert_select ".entrust-cell[data-ref=?] .stepper[aria-valuemax=3]", ref(@rare)
    assert_select ".entrust-cell[data-ref=?] .stepper", ref(@common), false
  end

  test "the page carries the sentence the button is described by and an empty polite status" do
    open_market!
    hold(@player, @rare.id, 2)
    sign_in(@player)

    get new_market_entrustment_path(locale: :en)

    assert_select "#entrust-not-returned", "Entrusted cards are not given back."
    assert_select "button[type=submit][aria-describedby=entrust-not-returned]"
    assert_select "#entrust-rare-note[hidden]"
    assert_select "[role=status][aria-live=polite]", text: ""
    assert_select "[data-entrust-recap-target=total] .picoin-amount__figure", "0"
  end

  test "the filters are inline chips with no sheet" do
    open_market!
    hold(@player, @rare.id, 2)
    sign_in(@player)

    get new_market_entrustment_path(locale: :fr)

    assert_select ".entrust-filters input[type=search]"
    assert_select ".entrust-filters .filter-chip", 6
    assert_select ".entrust-filters .filter-chip__text", "Doublons"
    assert_select ".entrust-filters input[data-entrust-filters-target=doubles][checked]"
    assert_select ".entrust-filters dialog, .entrust-filters .bottom-sheet", false
  end

  test "while only the first closed version exists, a visitor and a player both read the page and the player cannot validate" do
    Game::Market::CreateFirstSettings.new.call.value!
    hold(@player, @common.id, 1)

    get new_market_entrustment_path(locale: :en)
    assert_response :success

    sign_in(@player)
    assert_no_difference -> { Game::Market::LedgerEntry.count } do
      get new_market_entrustment_path(locale: :en)
    end
    assert_response :success
    assert_select ".market-entrust__notice", /closed/
    assert_select "button[disabled]"
  end

  test "a market closed after an opening shows the suspended banner with its link, and validation described by it" do
    close_market!(first_opened_at: 2.days.ago)
    hold(@player, @common.id, 1)
    sign_in(@player)

    get new_market_entrustment_path(locale: :en)

    assert_response :success
    assert_select "#market-suspended-banner[role=status]" do
      assert_select "h2", "THE MARKET IS SUSPENDED"
      assert_select "a[href=?]", market_path(locale: :en), "Back to the market"
    end
    assert_select ".market-entrust__notice", text: /closed for now/, count: 0
    assert_select "button[type=submit][disabled][aria-describedby='market-suspended-banner entrust-not-returned']"
    assert_select "[data-entrust-recap-reason-id-value=market-suspended-banner]"
  end

  test "a market never opened keeps the plain closed notice and no banner" do
    close_market!
    hold(@player, @common.id, 1)
    sign_in(@player)

    get new_market_entrustment_path(locale: :en)

    assert_select ".market-entrust__notice", /closed for now/
    assert_select "#market-suspended-banner", false
    assert_select "button[type=submit][disabled][aria-describedby=entrust-not-returned]"
  end

  test "a post while the market is suspended mints nothing and answers market_closed with the banner" do
    close_market!(first_opened_at: 2.days.ago)
    hold(@player, @common.id, 2)
    sign_in(@player)

    assert_no_difference -> { Game::Market::LedgerEntry.count } do
      post market_entrustments_path(locale: :en), params: { settings: "any", copies: { ref(@common) => "1" } }
    end

    assert_response :unprocessable_content
    assert_select ".market-entrust__refusal[role=alert]", "The market is closed for now."
    assert_select "#market-suspended-banner"
    assert_select ".entrust-cell[data-ref=?][data-ticked=1]", ref(@common)
  end

  test "validating entrusts the batch and shows the total minted and the count" do
    settings = open_market!
    hold(@player, @common.id, 2)
    hold(@player, @rare.id, 1)
    sign_in(@player)

    post market_entrustments_path(locale: :en), params: { settings: settings.token, copies: { ref(@common) => "2", ref(@rare) => "1", "unknown:9" => "4" } }

    assert_response :success
    assert_select ".market-entrust__total .picoin-amount[aria-label=?]", "7,000 PiCoins"
    assert_select ".market-entrust__count", "3 copies entrusted"
    assert_equal 0, Game::Holding.find_by(player_id: @player.id, card_season_id: @common.id).quantity
    assert_equal 7_000, Game::Market::Wallet.find_by!(player_id: @player.id).available
  end

  test "a closed market answers market_closed and the page keeps the ticks" do
    close_market!
    hold(@player, @common.id, 2)
    sign_in(@player)

    assert_no_difference -> { Game::Market::LedgerEntry.count } do
      post market_entrustments_path(locale: :fr), params: { settings: "any", copies: { ref(@common) => "1" } }
    end

    assert_response :unprocessable_content
    assert_select ".market-entrust__refusal[role=alert]", /Le marché est suspendu/
    assert_select "form#entrust > .market-entrust__refusal[role=alert][tabindex='-1']"
    assert_select "aside .market-entrust__refusal, dialog .market-entrust__refusal", false
    assert_nil flash[:alert]
    assert_select ".entrust-cell[data-ref=?][data-ticked=1]", ref(@common)
    assert_equal 2, Game::Holding.find_by(player_id: @player.id, card_season_id: @common.id).quantity
  end

  test "a stale version redraws the new amounts, keeps the ticks and charges nothing" do
    drawn = open_market!
    current = open_market!(entrustment_common: 1_500)
    hold(@player, @common.id, 2)
    sign_in(@player)

    post market_entrustments_path(locale: :en), params: { settings: drawn.token, copies: { ref(@common) => "2" } }

    assert_response :unprocessable_content
    assert_select "input[name=settings][value=?]", current.token
    assert_select "input[name=?][value=2]:not([disabled])", "copies[#{ref(@common)}]"
    assert_select ".market-entrust__refusal", /amounts changed/
    assert_select ".entrust-cell__value .picoin-amount[aria-label=?]", "1,500 PiCoins"
    assert_equal 0, Game::Market::LedgerEntry.count
  end

  test "a visitor cannot validate" do
    settings = open_market!

    post market_entrustments_path(locale: :en), params: { settings: settings.token, copies: { ref(@common) => "1" } }

    assert_redirected_to home_path(locale: :en)
  end

  test "an empty collection says there is nothing to entrust" do
    open_market!
    sign_in(@player)

    get new_market_entrustment_path(locale: :fr)

    assert_select ".market-entrust__notice", /Aucune carte à confier\./
  end

  test "the eleventh validation of a minute is throttled" do
    settings = open_market!
    sign_in(@player)

    with_counting_rate_limit(Market::EntrustmentsController) do
      11.times { post market_entrustments_path(locale: :en), params: { settings: settings.token, copies: {} } }
    end

    assert_redirected_to new_market_entrustment_path(locale: :en)
  end

  test "the lines are applied most valuable first whatever the form order" do
    settings = open_market!
    hold(@player, @common.id, 1)
    hold(@player, @rare.id, 1)
    Game::Market::Mint.credit(player_id: @player.id, amount: 1_195_000, settings_id: settings.id)
    sign_in(@player)

    post market_entrustments_path(locale: :en), params: { settings: settings.token, copies: { ref(@common) => "1", ref(@rare) => "1" } }

    assert_response :success
    assert_select ".market-entrust__total .picoin-amount[aria-label=?]", "5,000 PiCoins"
    assert_equal 1, Game::Holding.find_by(player_id: @player.id, card_season_id: @common.id).quantity
    assert_equal 0, Game::Holding.find_by(player_id: @player.id, card_season_id: @rare.id).quantity
  end

  test "a ticked ref that is no longer a free copy goes last and the batch is refused" do
    settings = open_market!
    hold(@player, @common.id, 1)
    sign_in(@player)

    assert_no_difference -> { Game::Market::LedgerEntry.count } do
      post market_entrustments_path(locale: :en), params: { settings: settings.token, copies: { ref(@rare) => "1", ref(@common) => "1" } }
    end

    assert_response :unprocessable_content
    assert_select ".market-entrust__refusal", /free copies/
    assert_select ".entrust-cell[data-ref=?][data-ticked=1]", ref(@common)
    assert_select ".entrust-cell[data-ticked=1]", 1
  end

  test "the result names a copy that stayed with its value and the cap left before the batch" do
    settings = open_market!
    legendary = catalog_card_seasons(:legendary_card_one)
    hold(@player, legendary.id, 1)
    hold(@player, @common.id, 1)
    Game::Market::Mint.credit(player_id: @player.id, amount: 1_150_000, settings_id: settings.id)
    sign_in(@player)

    post market_entrustments_path(locale: :en), params: { settings: settings.token, copies: { ref(legendary) => "1", ref(@common) => "1" } }

    assert_response :success
    assert_select ".market-entrust__total .picoin-amount[aria-label=?]", "1,000 PiCoins"
    assert_select "[role=status] .market-entrust__stayed-heading", "1 card was not entrusted"
    assert_select ".market-entrust__stayed-line", /1 copy stays in your collection/
    assert_select ".market-entrust__stayed-line .picoin-amount[aria-label=?]", "100,000 PiCoins"
    assert_select ".market-entrust__stayed-cap", /50,000/
    assert_select "[style]", false
    assert_equal 1, Game::Holding.find_by(player_id: @player.id, card_season_id: legendary.id).quantity
  end

  test "when nothing fits the page answers 422 with the renewal line and keeps the ticks" do
    settings = open_market!
    hold(@player, @common.id, 1)
    Game::Market::Mint.credit(player_id: @player.id, amount: 1_200_000, settings_id: settings.id)
    sign_in(@player)

    assert_no_difference -> { Game::Market::LedgerEntry.count } do
      post market_entrustments_path(locale: :fr), params: { settings: settings.token, copies: { ref(@common) => "1" } }
    end

    assert_response :unprocessable_content
    assert_select ".market-entrust__refusal", /00:00 UTC/
    assert_select "input[name=?][value=1]:not([disabled])", "copies[#{ref(@common)}]"
    assert_select "[data-entrust-cap-left-value=0]"
    assert_select "[style]", false
  end

  test "the ticks come back clamped to the free copies of the redrawn list" do
    settings = open_market!
    hold(@player, @common.id, 2)
    hold(@player, @rare.id, 1, reserved: 1)
    sign_in(@player)

    post market_entrustments_path(locale: :en), params: { settings: settings.token, copies: { ref(@common) => "5", ref(@rare) => "1" } }

    assert_response :unprocessable_content
    assert_select ".entrust-cell[data-ref=?][data-ticked=2]", ref(@common)
    assert_select ".entrust-cell[data-ref=?]", ref(@rare), false
    assert_select "input[name=?][value=2]", "copies[#{ref(@common)}]"
  end

  test "the cap left drawn is the daily cap less what was minted today" do
    settings = open_market!
    hold(@player, @common.id, 1)
    Game::Market::Mint.credit(player_id: @player.id, amount: 1_150_000, settings_id: settings.id)
    sign_in(@player)

    get new_market_entrustment_path(locale: :en)

    assert_select "form#entrust[data-entrust-cap-left-value=?]", "50000"
  end

  def second_edition_of(card_season)
    season = Catalog::Season.create!(status: :published, number: 2, published_at: Time.current)
    rows = [ { card_id: card_season.card_id, season_id: season.id, prestige_score: 0.5, rating: 50, rarity: card_season.rarity, number: 1 } ]
    Catalog::CardSeason.find(Catalog::CardSeason.insert_all!(rows, returning: :id).rows.flatten.sole)
  end

  test "the filtered page lists only that card's editions with doubles off and nothing ticked when there are two" do
    open_market!
    second = second_edition_of(@rare)
    hold(@player, @rare.id, 2)
    hold(@player, second.id, 1)
    hold(@player, @common.id, 3)
    sign_in(@player)

    assert_no_difference [ -> { Game::Holding.sum(:quantity) }, -> { Game::Market::LedgerEntry.count } ] do
      get new_market_card_entrustment_path(locale: :en, slug: @rare.card.slug)
    end

    assert_response :success
    assert_select ".entrust-cell", 2
    assert_select ".entrust-cell[data-ref=?]", ref(@common), false
    assert_select ".entrust-cell[data-ticked='0']", 2
    assert_select "form#entrust[data-entrust-doubles-value=false]"
    assert_select "input[name=card][value=?]", @rare.card.slug
    assert_select "input[data-entrust-filters-target=doubles][checked]", false
    assert_select ".market-entrust__card-only a[href=?]", new_market_entrustment_path(locale: :en)
  end

  test "a lone free edition opens ticked at one copy" do
    open_market!
    hold(@player, @rare.id, 2)
    sign_in(@player)

    get new_market_card_entrustment_path(locale: :en, slug: @rare.card.slug)

    assert_select ".entrust-cell[data-ref=?][data-ticked=1]", ref(@rare)
  end

  test "the unfiltered page keeps doubles on and carries no card" do
    open_market!
    hold(@player, @rare.id, 2)
    sign_in(@player)

    get new_market_entrustment_path(locale: :en)

    assert_select "form#entrust[data-entrust-doubles-value=true]"
    assert_select "input[name=card]", false
    assert_select "input[data-entrust-filters-target=doubles][checked]"
    assert_select ".entrust-cell[data-ticked='0']", 1
  end

  test "an unknown card token is not found" do
    open_market!
    sign_in(@player)

    get new_market_card_entrustment_path(locale: :en, slug: "nope")

    assert_response :not_found
  end

  test "a closed market still opens the filtered page with its notice" do
    close_market!
    hold(@player, @rare.id, 2)
    sign_in(@player)

    get new_market_card_entrustment_path(locale: :en, slug: @rare.card.slug)

    assert_response :success
    assert_select ".market-entrust__notice[role=status]"
  end

  test "a refused post from the filtered page redraws it filtered with the ticks kept" do
    drawn = open_market!
    open_market!
    second = second_edition_of(@rare)
    hold(@player, @rare.id, 2)
    hold(@player, second.id, 2)
    sign_in(@player)

    post market_entrustments_path(locale: :en), params: { settings: drawn.token, card: @rare.card.slug, copies: { ref(@rare) => "2" } }

    assert_response :unprocessable_content
    assert_select "input[name=card][value=?]", @rare.card.slug
    assert_select "form#entrust[data-entrust-doubles-value=false]"
    assert_select ".entrust-cell", 2
    assert_select ".entrust-cell[data-ref=?][data-ticked=2]", ref(@rare)
  end
end
