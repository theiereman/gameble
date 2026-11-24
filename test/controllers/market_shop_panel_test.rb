require "test_helper"
require_relative "../support/market"
require_relative "../support/market_listings"
require_relative "../support/steam_sign_in"

# On ANNONCES, the Brotherhood's shop shows a few Archive offers above the listings, and the grid mixes every offer in.
class MarketShopPanelTest < ActionDispatch::IntegrationTest
  include MarketListings
  include MarketSettings
  include SteamSignIn

  setup do
    @player = accounts_players(:player)
    @seller = accounts_players(:moderator)
    @common = catalog_card_seasons(:common_card_one)
    @uncommon = catalog_card_seasons(:uncommon_card_one)
    @rare = catalog_card_seasons(:rare_card_one)
    open_market!(first_opened_at: 1.day.ago, archive_price_common: 50, archive_price_rare: 500)
    Game::Market::ArchiveStock.create!(card_season_id: @common.id, quantity: 4)
    Game::Market::ArchiveStock.create!(card_season_id: @rare.id, quantity: 1)
    Game::Market::ArchiveDeposit.create!(player_id: @seller.id, card_season_id: @common.id, quantity: 4, updated_at: 3.days.ago)
    Game::Market::ArchiveDeposit.create!(player_id: @seller.id, card_season_id: @rare.id, quantity: 1, updated_at: 1.day.ago)
  end

  def panel_tiles = css_select(".shop-panel__list > li a")

  def grid_tiles = css_select("#market-tiles > li")

  test "a player reads the panel's count, its offers latest entrusted first, each opening the confirmation, and the link to the shop" do
    sign_in(@player)

    get market_path(locale: :fr)

    assert_response :success
    assert_select ".tabs__panel > .shop-panel:first-child"
    assert_select "section.shop-panel__frame h2", /BOUTIQUE DE LA CONFRÉRIE\s+2 cartes aux Archives/
    assert_select ".shop-panel__line", "Les Archives revendent les cartes confiées, à prix fixe."
    assert_equal [ new_market_archive_purchase_path(locale: :fr, slug: "blue-depths", number: 1),
      new_market_archive_purchase_path(locale: :fr, slug: "tin-soldier", number: 1) ], panel_tiles.map { it["href"] }
    assert_select ".shop-panel__list a[data-turbo-frame=archive-purchase][data-action='purchase-dialog#open']", 2
    assert_select ".shop-panel__list .archive-offer__stock", 0
    assert_select ".shop-panel__foot a.button--link[href=?][aria-label=?]", market_shop_path(locale: :fr),
      "Voir toute la boutique de la Confrérie", text: "Voir toute la boutique"
    assert_select ".market-screen[data-controller~=purchase-dialog] dialog#archive-purchase-dialog"
  end

  test "a wanted card comes first in the panel" do
    Game::Market::Wanted.create!(player_id: @player.id, card_id: @common.card_id, reason: "goal")
    sign_in(@player)

    get market_path(locale: :fr)

    assert_equal [ new_market_archive_purchase_path(locale: :fr, slug: "tin-soldier", number: 1),
      new_market_archive_purchase_path(locale: :fr, slug: "blue-depths", number: 1) ], panel_tiles.map { it["href"] }
    assert_select ".shop-panel__list li:first-child .archive-offer__tag--wanted", "VOULUE"
  end

  test "with nothing in the Archives the panel counts zero, draws its empty line and no link" do
    Game::Market::ArchiveStock.delete_all

    get market_path(locale: :fr)

    assert_select "section.shop-panel__frame h2", /0 carte aux Archives/
    assert_select ".shop-panel .empty-state__line", "Aucune carte aux Archives pour le moment."
    assert_select ".shop-panel__foot", 0
  end

  test "a visitor's tiles lead to the card detail, with no ACHETER and no dialog" do
    get market_path(locale: :en)

    assert_select ".shop-panel__list a[href=?]", card_season_path(locale: :en, slug: "blue-depths", number: 1)
    assert_select ".archive-offer__buy", 0
    assert_select "dialog#archive-purchase-dialog", 0
  end

  test "a suspended market keeps the panel readable, its tiles leading to the card detail" do
    close_market!(first_opened_at: 1.day.ago, archive_price_rare: 500)
    sign_in(@player)

    get market_path(locale: :en)

    assert_select ".shop-panel__list a[href=?]", card_season_path(locale: :en, slug: "blue-depths", number: 1)
    assert_select ".archive-offer__buy", 0
    assert_select "dialog#archive-purchase-dialog", 0
  end

  test "the grid mixes the offers into the listings under the chosen sort, with no tile id the shop uses" do
    cheap = listing!(seller: @seller, card_season: @common, starting_price: 80)
    dear = listing!(seller: @seller, card_season: @common, starting_price: 900)
    sign_in(@player)

    get market_path(locale: :fr, sort: "price_asc")

    assert_equal [ new_market_archive_purchase_path(locale: :fr, slug: "tin-soldier", number: 1),
      market_listing_path(locale: :fr, token: cheap.token),
      new_market_archive_purchase_path(locale: :fr, slug: "blue-depths", number: 1),
      market_listing_path(locale: :fr, token: dear.token) ], grid_tiles.map { css_select(it, "a").first["href"] }
    assert_select "#market-tiles .archive-offer__fixed", text: "prix fixe", count: 2
    assert_select "#market-tiles .archive-offer__stock", 0
    assert_select "[id^='archive-offer-']", 0
    assert_select "#market-tiles .archive-offer[data-archive-offer='blue-depths-1']"
    [ @common, @rare ].each { |card| assert_no_match(/(?:data-[a-z-]+|id|name|value|href)="[^"]*\b#{card.id}\b/, response.body) }
  end

  test "a search counts the listings and the Archive cards it finds" do
    listing!(seller: @seller, card_season: @rare, starting_price: 80)

    get market_path(locale: :fr, q: "bleues")

    assert_select ".market-screen__section-note", "1 annonce · 1 carte des Archives"

    get market_path(locale: :fr, q: "bleues", max_price: "100")

    assert_select ".market-screen__section-note", "1 annonce"
  end

  test "a search naming one game only the Archives hold shows its offers under the line to place an order" do
    sign_in(@player)

    get market_path(locale: :fr, q: "profondeurs bleues")

    assert_select ".market-searched__line", "Aucune annonce de joueur pour Profondeurs bleues."
    assert_select ".market-searched a.button--secondary[href=?]", new_market_card_order_path(locale: :fr, slug: "blue-depths"), text: "PASSER UN ORDRE"
    assert_equal 1, grid_tiles.size
    assert_select ".market-screen__section-note", "0 annonce · 1 carte des Archives"
  end

  test "a search naming one game nobody sells offers to place an order, disabled for a visitor" do
    get market_path(locale: :fr, q: "collines vertes")

    assert_select ".market-empty button.button--secondary[disabled]", "PASSER UN ORDRE"

    sign_in(@player)
    get market_path(locale: :fr, q: "collines vertes")

    assert_select ".market-empty .empty-state__line", "Aucune annonce pour Collines vertes."
    assert_select ".market-empty a.button--secondary[href=?]", new_market_card_order_path(locale: :fr, slug: "green-hills"), text: "PASSER UN ORDRE"
  end

  test "a search narrowed by another filter keeps the usual empty lines" do
    get market_path(locale: :fr, q: "collines vertes", rarity: [ "rare" ])

    assert_select ".market-empty__title", /Personne ne vend/
    assert_select ".market-empty .empty-state__line", 0
  end

  test "a search naming several games or none keeps the usual empty lines" do
    get market_path(locale: :fr, q: "nothing-matches")

    assert_select ".market-empty__title", /Personne ne vend/
    assert_select ".market-searched", 0
  end
end
