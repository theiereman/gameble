require "test_helper"
require_relative "../../support/holdings"
require_relative "../../support/market"
require_relative "../../support/market_auctions"
require_relative "../../support/market_orders"
require_relative "../../support/steam_sign_in"

class Market::BuyersControllerTest < ActionDispatch::IntegrationTest
  include Holdings
  include MarketAuctions
  include MarketOrders
  include MarketSettings
  include SteamSignIn

  setup do
    open_market!(first_opened_at: 1.day.ago)
    @player = accounts_players(:player)
    @rare = catalog_card_seasons(:rare_card_one)
    @common = catalog_card_seasons(:common_card_one)
  end

  def want_by_goal(card_season, *players)
    Game::Market::Wanted.insert_all(players.map { { player_id: it.id, card_id: card_season.card_id, reason: "goal", rarities: nil } })
  end

  def place(player, card_season, price)
    fund!(player, price)
    order!(player, card_season, price).tap { Game::Market::RebuildWanted.new.call(player:).value! }
  end

  def ref(card_season) = "#{card_season.card.slug}:#{card_season.season.number}"

  test "a visitor is sent to the landing" do
    get market_buyers_path(locale: :en)

    assert_redirected_to home_path(locale: :en)
  end

  test "the tab lists every wanted copy, most sought first, each a link to sell that edition, and the link to the filtered sale" do
    hold(@player, @rare.id)
    hold(@player, @common.id)
    place(accounts_players(:administrator), @rare, 100)
    want_by_goal(@rare, accounts_players(:moderator))
    want_by_goal(@common, accounts_players(:moderator))
    sign_in(@player)

    get market_buyers_path(locale: :fr)

    assert_response :success
    assert_select "title", /Acheteurs/
    assert_select ".market-screen__chips .tabs__tab--current[aria-current=page]", /ACHETEURS\s*2/
    assert_select ".market-screen__chips .tabs__tab--current .visually-hidden", "2 voulues"
    tiles = css_select(".tabs__panel .wanted-panel__tile")
    assert_equal [ new_market_card_sale_path(locale: :fr, slug: @rare.card.slug, ref: ref(@rare)),
      new_market_card_sale_path(locale: :fr, slug: @common.card.slug, ref: ref(@common)) ], tiles.map { it["href"] }
    assert_select tiles.first, ".wanted-panel__seekers", "2 joueurs la veulent"
    assert_select tiles.first, ".wanted-panel__order .picoin-amount__figure", "100"
    assert_select tiles.last, ".wanted-panel__no-order", "Aucun ordre"
    assert_match(/, 2 joueurs la veulent, ordre d'achat 100 PiCoins\. Mettre en vente\z/, tiles.first["aria-label"])
    assert_select ".wanted-panel__foot a.button--link[href=?][aria-label=?]", new_market_sale_path(locale: :fr, filter: { wanted: "1" }),
      "Tout voir, vos cartes voulues", text: "Tout voir"
    assert_no_match(/(?:data-[a-z-]+|id|name|value|href)="[^"]*\b#{@rare.id}\b/, response.body)
  end

  test "five wanted copies are all listed and counted on the chip" do
    %i[portal_one common_card_one uncommon_card_one rare_card_one legendary_card_one].each do |name|
      hold(@player, catalog_card_seasons(name).id)
      want_by_goal(catalog_card_seasons(name), accounts_players(:moderator))
    end
    sign_in(@player)

    get market_buyers_path(locale: :en)

    assert_select ".tabs__panel .wanted-panel__tile", 5
    assert_select ".market-screen__chips .tabs__tab--current .market-screen__badge", "5"
    assert_select ".market-screen__chips .tabs__tab--current .visually-hidden", "5 wanted"
  end

  test "with no wanted copy the tab draws its empty line and no see-all link" do
    hold(@player, @common.id)
    sign_in(@player)

    get market_buyers_path(locale: :fr)

    assert_select ".tabs__panel .empty-state", text: /Aucune de vos cartes n'est voulue pour le moment\./
    assert_select ".wanted-panel__tile", false
    assert_select ".wanted-panel__foot", false
    assert_select ".market-screen__chips .market-screen__badge", false
  end
end
