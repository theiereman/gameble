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
    assert_select ".market-entrust__cell", 2
    assert_select ".market-entrust__cell:first-child .market-entrust__value", "5,000 PiCoins"
    assert_select "input[name=?][max=2]", "copies[#{ref(@rare)}]"
    assert_select "[style]", false
    assert_select "[name=?]", "copies[#{@rare.id}]", false
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
    assert_select ".market-entrust__total", /7,000 PiCoins/
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
    assert_match "Le marché est fermé", flash[:alert]
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
    assert_select "input[name=?][value=2]", "copies[#{ref(@common)}]"
    assert_select ".market-entrust__value", "1,500 PiCoins"
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
end
