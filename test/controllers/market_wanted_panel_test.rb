require "test_helper"
require_relative "../support/holdings"
require_relative "../support/market"
require_relative "../support/market_auctions"
require_relative "../support/market_orders"
require_relative "../support/steam_sign_in"

# Above the market's chips, a signed-in player sees which of their copies other players want, the most sought first.
class MarketWantedPanelTest < ActionDispatch::IntegrationTest
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

  test "on ANNONCES and MES ORDRES the panel lists the wanted copies, most sought first, each a link to sell that edition" do
    hold(@player, @rare.id)
    hold(@player, @common.id)
    place(accounts_players(:administrator), @rare, 100)
    want_by_goal(@rare, accounts_players(:moderator))
    want_by_goal(@common, accounts_players(:moderator))
    sign_in(@player)

    [ market_path(locale: :fr), market_my_orders_path(locale: :fr) ].each do |path|
      get path

      assert_response :success
      assert_select ".market-screen .wanted-panel + nav.market-screen__chips"
      assert_select "section.wanted-panel__frame h2", /VOS CARTES VOULUES\s+2/
      tiles = css_select(".wanted-panel__tile")
      assert_equal [ new_market_card_sale_path(locale: :fr, slug: @rare.card.slug, ref: ref(@rare)),
        new_market_card_sale_path(locale: :fr, slug: @common.card.slug, ref: ref(@common)) ], tiles.map { it["href"] }
      assert_select tiles.first, ".wanted-panel__seekers", "2 joueurs la veulent"
      assert_select tiles.first, ".wanted-panel__order .picoin-amount__figure", "100"
      assert_select tiles.last, ".wanted-panel__no-order", "Aucun ordre"
      assert_match(/, 2 joueurs la veulent, ordre d'achat 100 PiCoins\. Mettre en vente\z/, tiles.first["aria-label"])
      assert_select ".wanted-panel__foot a.button--link[href=?][aria-label=?]", new_market_sale_path(locale: :fr, filter: { wanted: "1" }),
        "Tout voir, vos cartes voulues", text: "Tout voir"
    end
    assert_no_match(/(?:data-[a-z-]+|id|name|value|href)="[^"]*\b#{@rare.id}\b/, response.body)
  end

  test "with no wanted copy the panel keeps its place with its count at zero and its empty line, and no see-all link" do
    hold(@player, @common.id)
    sign_in(@player)

    get market_my_sales_path(locale: :fr)

    assert_select "section.wanted-panel__frame h2", /VOS CARTES VOULUES\s+0/
    assert_select ".wanted-panel .empty-state", text: /Aucune de vos cartes n'est voulue pour le moment\./
    assert_select ".wanted-panel__tile", false
    assert_select ".wanted-panel__foot", false
  end

  test "a visitor sees no panel" do
    get market_path(locale: :en)

    assert_response :success
    assert_select ".market-screen"
    assert_select ".wanted-panel", false
  end
end
