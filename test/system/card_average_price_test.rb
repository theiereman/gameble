require "application_system_test_case"
require_relative "../support/market"

class CardAveragePriceSystemTest < ApplicationSystemTestCase
  include MarketSettings

  setup do
    Game::Market::Settings.delete_all
    Game::Market::EditionPrice.create!(card_season_id: catalog_card_seasons(:portal_one).id, average: 15_000, sales_used: 5)
    Game::Market::EditionPrice.create!(card_season_id: catalog_card_seasons(:rare_card_one).id, average: 8_000, sales_used: 2)
  end

  test "a visitor reads the average price, few sales and no sale with their counts after the first opening" do
    open_market!(first_opened_at: 1.day.ago)

    visit card_path(locale: :en, slug: "portal")
    assert_selector ".public-card__price .picoin-amount__figure", text: "15,000"
    assert_selector ".public-card__price .average-price__basis", text: "Based on 5 sales"
    assert_no_selector ".public-card__price .average-price__few"

    visit card_path(locale: :en, slug: "blue-depths")
    assert_selector ".public-card__price .average-price__few", text: "few sales"
    assert_selector ".public-card__price .average-price__basis", text: "Based on 2 sales"

    visit card_path(locale: :en, slug: "tin-soldier")
    assert_selector ".public-card__price", text: "No sale"
    assert_no_selector ".public-card__price .average-price__basis"
  end

  test "no price shows before the market's first opening" do
    open_market!

    visit card_path(locale: :en, slug: "portal")

    assert_selector ".public-card h1", text: "Portal"
    assert_no_selector ".public-card__price"
  end
end
