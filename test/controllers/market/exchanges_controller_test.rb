require "test_helper"
require_relative "../../support/market"
require_relative "../../support/market_snapshots"
require_relative "../../support/steam_sign_in"

class Market::ExchangesControllerTest < ActionDispatch::IntegrationTest
  include MarketSettings
  include MarketSnapshots
  include SteamSignIn

  setup do
    clear_snapshots
    Game::Market::ChartPublication.delete_all
    open_market!(first_opened_at: 40.days.ago)
    @yesterday = Time.current.utc.to_date - 1
  end

  teardown { clear_snapshots }

  def month_of_snapshots
    30.times do |ago|
      snapshot!(@yesterday - ago, created: 10_000, destroyed_total: 5_600, circulation: 412_600_000 - (ago * 4_400))
    end
  end

  test "staff read the Reactor: its four headline figures and its two charts with their tables" do
    month_of_snapshots
    sign_in(accounts_players(:moderator))

    get market_exchange_path(locale: :en)

    assert_response :success
    assert_select "h1", "The Brotherhood's Exchange"
    assert_select "section[data-exchange-panel=reactor] h2", "THE BROTHERHOOD'S REACTOR"
    assert_select ".chart-figures__item", 4
    assert_select ".chart-figures__value", text: /412.6M/
    assert_select ".chart-figures__value", text: /300k/
    assert_select ".chart-figures__value", text: /56%/
    assert_select "[data-exchange-panel=reactor] figure.chart h3", 2
    assert_select "figure#reactor-flows tbody tr", 30
    assert_select "figure#reactor-flows tbody tr:first-child th time[datetime=?]", @yesterday.iso8601
    assert_select "figure#reactor-flows tbody tr:first-child td", text: /4,400/
    assert_select "figure#reactor-circulation tbody tr", 30
    assert_select "#reactor-flows-summary", "Over 30 days, 300,000 PiCoins minted and 168,000 destroyed (56%). 412,600,000 in circulation."
    assert_select "[style]", false
  end

  test "staff read it in French" do
    month_of_snapshots
    sign_in(accounts_players(:administrator))

    get market_exchange_path(locale: :fr)

    assert_select "h1", "La Bourse de la Confrérie"
    assert_select ".chart-figures__label", "DÉTRUITS / FRAPPÉS"
    assert_select "details summary .chart__table-show", "VOIR LE TABLEAU"
  end

  test "with no snapshot staff read dashes and a sentence saying so" do
    sign_in(accounts_players(:moderator))

    get market_exchange_path(locale: :en)

    assert_response :success
    assert_select ".chart-figures__value", text: /—/, count: 4
    assert_select "#reactor-flows-summary", "No figure over these 30 days yet."
  end

  def publish(kind) = Game::Market::PublishChart.new.call(player: accounts_players(:administrator), kind:).value!

  test "while nothing is published a visitor and a player get not found" do
    month_of_snapshots

    get market_exchange_path(locale: :en)
    assert_response :not_found

    sign_in(accounts_players(:player))
    get market_exchange_path(locale: :en)
    assert_response :not_found
  end

  test "an unpublished Reactor is flagged for staff inside its title" do
    month_of_snapshots
    sign_in(accounts_players(:moderator))

    get market_exchange_path(locale: :en)

    assert_select "figure#reactor-flows figcaption h3 .chart__staff-flag", "VISIBLE TO STAFF"
    assert_select "figure#reactor-circulation figcaption .chart__staff-flag", "VISIBLE TO STAFF"
  end

  test "once the Reactor is published a visitor and staff get it unflagged" do
    month_of_snapshots
    publish("reactor")

    get market_exchange_path(locale: :en)
    assert_response :success
    assert_select "[data-exchange-panel=reactor] turbo-frame#exchange-chart-reactor"
    assert_select ".chart__staff-flag", false

    sign_in(accounts_players(:moderator))
    get market_exchange_path(locale: :en)
    assert_select "turbo-frame#exchange-chart-reactor"
    assert_select "[data-exchange-panel=reactor] .chart__staff-flag", false
  end

  test "the edition chart alone published keeps the exchange hidden" do
    publish("edition_sales")

    get market_exchange_path(locale: :en)

    assert_response :not_found
  end

  test "the rarity prices alone published open the exchange without the Reactor" do
    publish("rarity_prices")

    get market_exchange_path(locale: :en)

    assert_response :success
    assert_select "[data-exchange-panel=reactor]", false
    assert_select "[data-exchange-panel=rarity_prices] h2", "WHAT A CARD COSTS"
    assert_select "[data-exchange-panel=rarity_prices] turbo-frame#exchange-chart-rarity-prices[loading=lazy]"
  end

  test "staff read the unpublished rarity prices inline, flagged" do
    month_of_snapshots
    sign_in(accounts_players(:administrator))

    get market_exchange_path(locale: :fr)

    assert_select "[data-exchange-panel=rarity_prices] h2", "CE QUE COÛTE UNE CARTE"
    assert_select ".rarity-tiles > li", 5
    assert_select "figure#rarity-index figcaption .chart__staff-flag", "VISIBLE PAR LE STAFF"
  end

  test "before the market's first opening nobody, staff included, finds the exchange" do
    Game::Market::Settings.delete_all
    close_market!
    publish("reactor")

    get market_exchange_path(locale: :en)
    assert_response :not_found

    sign_in(accounts_players(:administrator))
    get market_exchange_path(locale: :en)
    assert_response :not_found
  end

  test "a suspended market keeps the exchange" do
    close_market!(first_opened_at: 40.days.ago)
    publish("reactor")

    get market_exchange_path(locale: :en)

    assert_response :success
    assert_select "turbo-frame#exchange-chart-reactor"
  end

  test "the market screen links to the exchange only while one of its charts is visible" do
    get market_path(locale: :en)
    assert_select "a[href=?]", market_exchange_path(locale: :en), false

    publish("edition_sales")
    get market_path(locale: :en)
    assert_select "a[href=?]", market_exchange_path(locale: :en), false

    publish("reactor")
    get market_path(locale: :en)
    assert_select ".market-screen__chips a[href=?]", market_exchange_path(locale: :en), "THE BROTHERHOOD'S EXCHANGE"
  end

  test "staff see the link before anything is published" do
    sign_in(accounts_players(:moderator))

    get market_path(locale: :fr)

    assert_select ".market-screen__chips a[href=?]", market_exchange_path(locale: :fr), "LA BOURSE DE LA CONFRÉRIE"
  end
end
