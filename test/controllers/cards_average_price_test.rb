require "test_helper"
require_relative "../support/holdings"
require_relative "../support/market"
require_relative "../support/second_season"
require_relative "../support/steam_sign_in"

# The card detail's "Prix moyen" row: the edition's average with its sale count, for a visitor and a player,
# in each state, and nothing before the market's first opening.
class CardsAveragePriceTest < ActionDispatch::IntegrationTest
  include Holdings
  include MarketSettings
  include SecondSeason
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

  def edition_lines = css_select(".card-detail__editions li").map { it.text.squish }

  test "each owned edition is a line of EDITIONS with its own price" do
    open_market!(first_opened_at: 1.day.ago)
    player = accounts_players(:moderator)
    season, = publish_second_season(player, held: [])
    second = Catalog::CardSeason.find_by!(card_id: @priced.card_id, season_id: season.id)
    Game::Market::EditionPrice.create!(card_season_id: second.id, average: 40_000, sales_used: 3)
    hold(player, @priced.id, 1)
    hold(player, second.id, 1)
    sign_in(player)

    get card_season_path(locale: :en, slug: "portal", number: 2)

    assert_equal [ "Epic · S2 40k", "Epic · S1 15k" ].sort, edition_lines.sort
    assert_select ".card-detail__editions .picoin-amount[aria-label='40,000 PiCoins']"
    assert_select ".card-detail__editions .picoin-amount[aria-label='15,000 PiCoins']"
  end

  test "an owned edition with no sale says so in EDITIONS" do
    open_market!(first_opened_at: 1.day.ago)
    player = accounts_players(:moderator)
    hold(player, catalog_card_seasons(:common_card_one).id, 1)
    sign_in(player)

    get card_path(locale: :en, slug: "tin-soldier")

    assert_select ".card-detail__editions li .average-price--none", "No sale"
  end

  test "EDITIONS keeps its grouped lines before the first opening" do
    open_market!
    player = accounts_players(:moderator)
    hold(player, @priced.id, 1)
    sign_in(player)

    get card_path(locale: :en, slug: "portal")

    assert_equal [ "Epic: S1" ], edition_lines
    assert_select ".card-detail__editions .picoin-amount", false
  end

  test "the card's neighbours follow the grid sorted by price" do
    open_market!(first_opened_at: 1.day.ago)
    sign_in(accounts_players(:moderator))

    get card_season_path(locale: :en, slug: "blue-depths", number: 1, grid: { sort: "price_desc" })

    assert_select ".card-detail__position", /2 \/ 5/
    assert_select ".card-detail__nav[href*='portal']"
    assert_select ".card-detail__nav[href*='grid%5Bsort%5D=price_desc']", 2
  end
end
