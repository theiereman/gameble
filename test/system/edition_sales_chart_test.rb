require "application_system_test_case"
require_relative "../support/market"
require_relative "../support/market_sales"
require_relative "../support/steam_sign_in"

class EditionSalesChartTest < ApplicationSystemTestCase
  include MarketSettings
  include MarketSales
  include SteamSignIn

  setup do
    Game::Market::ChartPublication.delete_all
    open_market!(first_opened_at: 60.days.ago)
    @edition = catalog_card_seasons(:rare_card_one)
  end

  def sign_in_as(player)
    mock_steam_sign_in(player.steam_id)
    visit home_path(locale: :en)
    click_steam_sign_in
    assert_signed_in
  end

  def visit_detail(edition = @edition) = visit(card_season_path(locale: :en, slug: edition.card.slug, number: edition.season.number))

  def sell(*prices)
    prices.each_with_index { |price, index| sold!(@edition, price, sold_at: (prices.size - index).hours.ago, average_after_sale: price) }
    row = Game::Market::EditionPrice.find_or_initialize_by(card_season_id: @edition.id)
    sales_used = row.sales_used + prices.size
    row.update!(average: prices.max, sales_used:, refreshed_at: Time.current)
  end

  test "the edition chart's four states on a card detail, and a new sale moving its fragment" do
    sell(2_400, 2_200)
    sign_in_as(accounts_players(:moderator))
    visit_detail
    within("figure#edition-sales") do
      assert_selector "h2", text: "SALES OF THIS EDITION"
      assert_selector ".chart__staff-flag", text: "VISIBLE TO STAFF"
    end

    sign_out
    assert_signed_out
    sign_in_as(accounts_players(:player))
    visit_detail
    assert_selector ".card-detail__fact--price"
    assert_no_selector "#edition-sales"

    Game::Market::PublishChart.new.call(player: accounts_players(:administrator), kind: "edition_sales").value!
    visit_detail
    within("figure#edition-sales") do
      assert_selector "canvas[style*=height]"
      assert_no_selector ".chart__staff-flag"
      assert_text(/2 sales in \d+ days, too few sales for an average price/)
      assert_no_selector ".chart__legend-item", text: "Average price"
    end
    first_src = find("turbo-frame#card-edition-sales")["src"]

    sell(3_000)
    visit_detail
    within("figure#edition-sales") do
      assert_selector ".chart__legend-item", text: "Average price"
      assert_selector "canvas[style*=height]"
    end
    assert_not_equal first_src, find("turbo-frame#card-edition-sales")["src"]

    visit_detail(catalog_card_seasons(:uncommon_card_one))
    assert_selector "#card-detail-heading"
    assert_no_selector "#card-edition-sales"
  end
end
