require "test_helper"
require_relative "../support/market"
require_relative "../support/steam_sign_in"

# The card detail's "Prix moyen" row: the edition's average with its sale count, for a visitor and a player,
# in each state, and nothing before the market's first opening.
class CardsAveragePriceTest < ActionDispatch::IntegrationTest
  include MarketSettings
  include SteamSignIn

  setup do
    @priced = catalog_card_seasons(:portal_one)
    @few = catalog_card_seasons(:rare_card_one)
    Game::Market::EditionPrice.create!(card_season_id: @priced.id, average: 15_000, sales_used: 5)
    Game::Market::EditionPrice.create!(card_season_id: @few.id, average: 8_000, sales_used: 2)
  end

  def price_label = css_select(".card-detail__fact--price dt").sole.text

  test "a player sees the amount with its sale count for an edition with five sales" do
    open_market!(first_opened_at: 1.day.ago)
    sign_in(accounts_players(:moderator))

    get card_path(locale: :en, slug: "portal")

    assert_equal "Average price S1", price_label
    assert_select ".card-detail__fact--price .picoin-amount[aria-label='15,000 PiCoins']"
    assert_select ".card-detail__fact--price .average-price__basis", "Based on 5 sales"
    assert_select ".card-detail__fact--price .average-price__few", false
  end

  test "two sales show the amount with few sales and their count" do
    open_market!(first_opened_at: 1.day.ago)
    sign_in(accounts_players(:moderator))

    get card_path(locale: :en, slug: "blue-depths")

    assert_select ".card-detail__fact--price .picoin-amount[aria-label='8,000 PiCoins']"
    assert_select ".card-detail__fact--price .average-price__few", "few sales"
    assert_select ".card-detail__fact--price .average-price__basis", "Based on 2 sales"
  end

  test "an edition with no sale says so, without a count" do
    open_market!(first_opened_at: 1.day.ago)
    sign_in(accounts_players(:moderator))

    get card_path(locale: :en, slug: "tin-soldier")

    assert_select ".card-detail__fact--price .average-price--none", "No sale"
    assert_select ".card-detail__fact--price .average-price__basis", false
  end

  test "a visitor on the public card page reads the price too, in French" do
    open_market!(first_opened_at: 1.day.ago)

    get card_path(locale: :fr, slug: "portal")

    assert_select ".public-card__price-label", "Prix moyen S1"
    assert_select ".public-card__price .picoin-amount"
    assert_select ".public-card__price .average-price__basis", "Fondé sur 5 ventes"
  end

  test "nothing shows before the market's first opening for a player" do
    open_market!
    sign_in(accounts_players(:moderator))

    get card_path(locale: :en, slug: "portal")

    assert_select ".card-detail__fact--price", false
  end

  test "nothing shows before the market's first opening for a visitor" do
    open_market!

    get card_path(locale: :en, slug: "portal")

    assert_select ".public-card__price", false
  end

  test "the price row is on the card detail of a closed market that has opened once" do
    open_market!(first_opened_at: 2.days.ago)
    close_market!(first_opened_at: 2.days.ago)
    sign_in(accounts_players(:moderator))

    get card_path(locale: :en, slug: "portal")

    assert_select ".card-detail__fact--price"
  end

  test "the card face carries no price" do
    open_market!(first_opened_at: 1.day.ago)
    sign_in(accounts_players(:moderator))

    get card_path(locale: :en, slug: "portal")

    assert_select ".card-detail__card .picoin-amount", false
  end
end
