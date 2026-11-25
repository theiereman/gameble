require "test_helper"
require_relative "../../support/steam_sign_in"
require_relative "../../support/market"
require_relative "../../support/archive_at_reference"

class Market::ShopsControllerTest < ActionDispatch::IntegrationTest
  include ArchiveAtReference
  include MarketSettings
  include SteamSignIn

  setup do
    @player = accounts_players(:player)
    @common = catalog_card_seasons(:common_card_one)
    @epic = catalog_card_seasons(:portal_one)
    @rare = catalog_card_seasons(:rare_card_one)
    @settings = open_market!(first_opened_at: 1.day.ago, archive_price_common: 50, archive_price_rare: 500)
    { @common => 4, @epic => 2, @rare => 1 }.each { |card, quantity| Game::Market::ArchiveStock.create!(card_season_id: card.id, quantity:) }
  end

  def tiles = css_select("#archive-offers > li")

  test "a visitor reads the tiles with their price and stock, the sign-in line, and each tile leads to the card detail" do
    get market_shop_path(locale: :fr)

    assert_response :success
    assert_select "h1.visually-hidden", "Boutique de la Confrérie"
    assert_select ".market-shop__sign-in a", "Connectez-vous pour acheter aux Archives"
    assert_equal 2, tiles.size
    assert_select "#archive-offer-blue-depths-1 a[href=?]", card_season_path(locale: :fr, slug: "blue-depths", number: 1)
    assert_select "#archive-offer-blue-depths-1 .archive-offer__stock", "1 en stock"
    assert_no_match(/prix du jour/, response.body)
    assert_select ".archive-offer__buy", 0
    assert_select "dialog#archive-purchase-dialog", 0
    assert_select ".market-filters__wanted", 0
    assert_select ".market-shop__count", "2 cartes · 2 éditions"
  end

  test "a player's tiles open the confirmation in the dialog, with their accessible name" do
    sign_in(@player)

    get market_shop_path(locale: :fr)

    assert_select "dialog#archive-purchase-dialog turbo-frame#archive-purchase"
    assert_select "#archive-offer-blue-depths-1 a[href=?][data-turbo-frame=archive-purchase][data-action='purchase-dialog#open']",
      new_market_archive_purchase_path(locale: :fr, slug: "blue-depths", number: 1)
    assert_select "#archive-offer-blue-depths-1 a[aria-label^='Profondeurs bleues, Rare, saison 1, Archives de la Confrérie, 500']" \
      "[aria-label*=', 1 en stock']"
    assert_select ".archive-offer__cap[data-archive-cap]", text: "", count: 2
    cap, buy = css_select("#archive-offer-blue-depths-1 a").first["aria-describedby"].split
    assert_select "##{cap}.visually-hidden[data-archive-cap=rare]", ""
    assert_select "##{buy}.visually-hidden[data-archive-buy=rare]", "Acheter"
    assert_select ".archive-offer__buy", 2
  end

  def week_of_purchases!
    5.times do
      Game::Market::ArchiveWithdrawal.create!(player_id: @player.id, card_season_id: @common.id, purchase_token: SecureRandom.base58(24),
        price: 50, settings_id: @settings.id, created_at: Time.current)
    end
    Time.current.utc.beginning_of_week + 1.week
  end

  test "after a week's purchases every tile and chip reads the next Monday, in both languages" do
    sign_in(@player)
    reopens = week_of_purchases!
    text = reopens.strftime("%Y-%m-%d %H:%M UTC")

    get market_shop_path(locale: :fr)
    assert_select "#archive-offer-blue-depths-1 .archive-offer__cap", "5 achats aux Archives par semaine · prochain le #{text}"
    assert_select "#archive-offer-tin-soldier-1 .archive-offer__cap", 1
    described = css_select("#archive-offer-blue-depths-1 a").first["aria-describedby"]
    assert_select "##{described}.visually-hidden[data-archive-cap=rare]", /5 achats/
    assert_select ".archive-offer__buy", 0
    assert_select "[data-archive-buy]", 0
    assert_equal [ described ], css_select("#archive-offer-blue-depths-1 a").first["aria-describedby"].split

    get market_shop_path(locale: :en)
    assert_select "#archive-offer-blue-depths-1 .archive-offer__cap", "5 Archive purchases a week · next on #{text}"
    assert_select "#archive-offer-blue-depths-1 .archive-offer__cap time[datetime=?][data-controller=local-time]", reopens.iso8601
    assert_select ".market-shop__rarity-cap", 3
  end

  test "the next Monday is drawn in the viewer's time zone" do
    sign_in(@player)
    reopens = week_of_purchases!
    cookies[:time_zone] = "Pacific/Auckland"

    get market_shop_path(locale: :en)

    local = I18n.l(reopens.in_time_zone("Pacific/Auckland"), format: :local_datetime, locale: :en)
    assert_select "#archive-offer-blue-depths-1 .archive-offer__cap", "5 Archive purchases a week · next on #{local}"
  end

  test "a visitor reads no cap line" do
    get market_shop_path(locale: :fr)

    assert_select ".archive-offer__cap", 0
    assert_select ".market-shop__rarity-cap", 0
    assert_select ".listing-tile__mark", 0
  end

  test "a wanted card wears the VOULUE tag and the chip counts the wanted offers" do
    Game::Market::Wanted.create!(player_id: @player.id, card_id: @rare.card_id, reason: "goal")
    sign_in(@player)

    get market_shop_path(locale: :fr)

    assert_select "#archive-offer-blue-depths-1 .archive-offer__tag--wanted", "VOULUE"
    assert_select "#archive-offer-tin-soldier-1 .archive-offer__tag--wanted", 0
    assert_select "#archive-offer-blue-depths-1 .listing-tile__mark", 0
    assert_select "#archive-offer-tin-soldier-1 .listing-tile__mark--missing", "Non possédée"
    assert_select "#archive-offer-blue-depths-1 a[aria-label$=', voulue']"
    assert_select ".market-filters__wanted", /VOULUES · 1/
    assert_select ".market-filters__wanted input[aria-label=?]", "Voulues, 1 carte"

    get market_shop_path(locale: :en, wanted: "1")

    assert_equal [ "archive-offer-blue-depths-1" ], tiles.map { it["id"] }
  end

  test "an Epic is not in the shop, nor among the rarity chips" do
    get market_shop_path(locale: :en)

    assert_select "#archive-offer-portal-1", 0
    assert_select ".market-shop__rarities input[name='rarity[]']", 3
    assert_select ".market-shop__rarities input[value=epic]", 0
  end

  test "prices sort ascending by default, and the filters stay in the sort and season links" do
    get market_shop_path(locale: :en, sort: "price_desc", rarity: [ "rare", "epic" ], q: "blue")

    assert_equal [ "archive-offer-blue-depths-1" ], tiles.map { it["id"] }
    assert_select ".sort__option[href*='sort=price_asc'][href*='rarity%5B%5D=rare'][href*='q=blue']"
    assert_select ".sort__option[href*='season%5B%5D=1'][href*='rarity%5B%5D=rare']"
    assert_select ".sort__option[href*='epic']", 0

    get market_shop_path(locale: :en)

    assert_equal %w[archive-offer-tin-soldier-1 archive-offer-blue-depths-1], tiles.map { it["id"] }
  end

  test "empty Archives draw the empty line, and filters matching nothing the no-match line" do
    get market_shop_path(locale: :fr, q: "nothing-matches")

    assert_select ".empty-state__line", "Aucune carte des Archives ne correspond à ces filtres."
    assert_select "#archive-offers", 0

    Game::Market::ArchiveStock.delete_all
    get market_shop_path(locale: :fr)

    assert_select ".empty-state__line", "Aucune carte aux Archives pour le moment."
  end

  test "the next page arrives as a stream appending tiles" do
    get market_shop_path(locale: :en, page: 1, format: :turbo_stream)

    assert_response :success
    assert_equal "text/vnd.turbo-stream.html", response.media_type
    assert_select "turbo-stream[action=append][target=archive-offers] template li", 2
    assert_select "turbo-stream[action=replace][target=shop-pages]"
  end

  test "the shop is a 404 before the market first opened" do
    forget_market!
    open_market!(open: false, archive_price_rare: 500)

    get market_shop_path(locale: :en)

    assert_response :not_found
  end

  test "a suspended market keeps the shop readable with its banner and no ACHETER" do
    close_market!(first_opened_at: 1.day.ago, archive_price_rare: 500)
    sign_in(@player)

    get market_shop_path(locale: :en)

    assert_select "#market-suspended-banner"
    assert_select ".archive-offer__buy", 0
    assert_select "#archive-offer-blue-depths-1 a[href=?]", card_season_path(locale: :en, slug: "blue-depths", number: 1)
    assert_select "dialog#archive-purchase-dialog", 0
  end

  test "no database id reaches the page" do
    sign_in(@player)

    get market_shop_path(locale: :en)

    [ @common, @rare ].each { |card| assert_no_match(/\b#{card.id}\b/, response.body) }
  end
end
