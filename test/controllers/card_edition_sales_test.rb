require "test_helper"
require_relative "../support/market"
require_relative "../support/market_sales"
require_relative "../support/steam_sign_in"

class CardEditionSalesTest < ActionDispatch::IntegrationTest
  include MarketSettings
  include MarketSales
  include SteamSignIn

  setup do
    Game::Market::ChartPublication.delete_all
    open_market!(first_opened_at: 60.days.ago)
    @edition = catalog_card_seasons(:rare_card_one)
    @detail_path = card_season_path(locale: :en, slug: @edition.card.slug, number: @edition.season.number)
  end

  def publish(kind) = Game::Market::PublishChart.new.call(player: accounts_players(:administrator), kind:).value!

  def sell(*prices)
    prices.each_with_index { |price, index| sold!(@edition, price, sold_at: (prices.size - index).days.ago, average_after_sale: price) }
    row = Game::Market::EditionPrice.find_or_initialize_by(card_season_id: @edition.id)
    row.update!(average: prices.sum / prices.size, sales_used: prices.size + row.sales_used, refreshed_at: Time.current)
  end

  def edition_version = ChartVersions::EditionSales.of(slug: @edition.card.slug, season_number: @edition.season.number).version

  def edition_path(version = edition_version, locale: :en) = chart_fragment_path(locale:, kind: "edition_sales", version:)

  test "unpublished, a player reads only the average price row" do
    sell(2_400, 2_200, 3_000)
    sign_in(accounts_players(:player))

    get @detail_path

    assert_select ".card-detail__fact--price"
    assert_select "#card-edition-sales", false
    assert_select "#edition-sales", false
  end

  test "published, the card detail embeds the edition chart as a lazy frame" do
    sell(2_400, 2_200, 3_000)
    publish("edition_sales")
    sign_in(accounts_players(:player))

    get @detail_path

    assert_select "turbo-frame#card-edition-sales[loading=lazy][src=?]", edition_path
  end

  test "an edition never sold shows no chart" do
    publish("edition_sales")
    sign_in(accounts_players(:player))

    get @detail_path

    assert_select "#card-edition-sales", false
  end

  test "staff read an unpublished edition chart inline, flagged" do
    sell(2_400, 2_200)
    sign_in(accounts_players(:moderator))

    get @detail_path

    assert_select "turbo-frame#card-edition-sales", false
    assert_select "figure#edition-sales h2 .chart__staff-flag", "VISIBLE TO STAFF"
    assert_select "figure#edition-sales #edition-sales-summary", /too few sales for an average price/
  end

  test "the fragment draws every sale, the average and the floor, cached by the price row's fingerprint" do
    sell(2_400, 2_200, 3_000)
    publish("edition_sales")

    get edition_path(locale: :fr)

    assert_response :success
    assert_equal "max-age=31536000, public, immutable", response.headers["Cache-Control"]
    assert_nil response.headers["Set-Cookie"]
    assert_select "turbo-frame#card-edition-sales figure#edition-sales"
    assert_select "#edition-sales-table tbody tr", 3
    assert_select "#edition-sales-summary", /3 ventes en \d+ jours.*prix moyen/
    assert_select ".chart__legend-item", text: /Plancher Rare/
    series = JSON.parse(css_select("figure#edition-sales").first["data-chart-series-value"])
    assert_equal %w[kind labels series x], series.keys.sort
    assert_equal %w[average floor rare], series["series"].keys.sort
  end

  test "a new sale changes the fragment's address, and the old one is not found" do
    sell(2_400, 2_200, 3_000)
    publish("edition_sales")
    before = edition_version

    travel 1.minute do
      sell(2_600)
      assert_not_equal before, edition_version

      get edition_path(before)
      assert_response :not_found
      get edition_path
      assert_response :success
    end
  end

  test "an unknown edition is not found" do
    publish("edition_sales")

    get edition_path("1-3-1762765200-no-such-card")

    assert_response :not_found
  end
end
