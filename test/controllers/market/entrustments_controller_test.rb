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
    assert_select ".entrust-recap__refusal[role=alert]", /Le marché est fermé/
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
    assert_select ".entrust-recap__refusal", /amounts changed/
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
    assert_select ".entrust-recap__refusal", /free copies/
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
    assert_select ".entrust-recap__refusal", /00:00 UTC/
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
end
