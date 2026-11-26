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

  test "the tab lists every wanted copy, buy orders first and framed, each a link to sell that edition, and the link to the filtered sale" do
    hold(@player, @rare.id, 2)
    hold(@player, @common.id)
    place(accounts_players(:administrator), @rare, 100)
    want_by_goal(@rare, accounts_players(:moderator))
    want_by_goal(@common, accounts_players(:moderator))
    sign_in(@player)

    get market_buyers_path(locale: :fr)

    assert_response :success
    assert_select "title", /Recherchées/
    assert_select ".market-screen__chips .tabs__tab--current[aria-current=page]", /RECHERCHÉES\s*1/
    assert_select ".market-screen__chips .tabs__tab--current .visually-hidden", "1 avec un ordre d'achat"
    tiles = css_select(".tabs__panel .wanted-panel__tile")
    assert_equal [ new_market_card_sale_path(locale: :fr, slug: @rare.card.slug, ref: ref(@rare)),
      new_market_card_sale_path(locale: :fr, slug: @common.card.slug, ref: ref(@common)) ], tiles.map { it["href"] }
    assert_includes tiles.first["class"], "wanted-panel__tile--order"
    assert_not_includes tiles.last["class"], "wanted-panel__tile--order"
    assert_select tiles.first, ".wanted-panel__kind", "ORDRE D'ACHAT"
    assert_select tiles.first, ".wanted-panel__seekers", "2 joueurs la veulent"
    assert_select tiles.first, ".wanted-panel__order .picoin-amount__figure", "100"
    assert_select tiles.last, ".wanted-panel__kind", "OBJECTIF"
    assert_select tiles.last, ".wanted-panel__order", false
    assert_select tiles.first, ".listing-tile__mark--owned", "Possédée ×2"
    assert_select tiles.last, ".listing-tile__mark--owned", "Possédée ×1"
    assert_match(/, 2 joueurs la veulent, ordre d'achat 100 PiCoins, 2 exemplaires dans votre collection\. Mettre en vente\z/, tiles.first["aria-label"])
    assert_select ".wanted-panel__foot a.button--link[href=?][aria-label=?]", new_market_sale_path(locale: :fr, filter: { wanted: "1" }),
      "Tout voir, vos cartes voulues", text: "Tout voir"
    assert_no_match(/(?:data-[a-z-]+|id|name|value|href)="[^"]*\b#{@rare.id}\b/, response.body)
  end

  test "copies wanted only by goals are all listed but leave the chip without a badge" do
    %i[portal_one common_card_one uncommon_card_one rare_card_one legendary_card_one].each do |name|
      hold(@player, catalog_card_seasons(name).id)
      want_by_goal(catalog_card_seasons(name), accounts_players(:moderator))
    end
    sign_in(@player)

    get market_buyers_path(locale: :en)

    assert_select ".tabs__panel .wanted-panel__tile", 5
    assert_select ".market-screen__chips .market-screen__badge", false
  end

  test "the kind filter keeps the buy orders or the goals, and the rarity filter one rarity, each keeping the other" do
    hold(@player, @rare.id)
    hold(@player, @common.id)
    place(accounts_players(:administrator), @rare, 100)
    want_by_goal(@common, accounts_players(:moderator))
    sign_in(@player)

    get market_buyers_path(locale: :en)
    assert_select ".wanted-panel__filters button[name=kind][aria-pressed=true]", "All"
    assert_select ".wanted-panel__filters button[name=rarity]", 3
    assert_select ".wanted-panel__tile", 2

    get market_buyers_path(locale: :en, kind: "orders")
    assert_equal [ ref(@rare) ], css_select(".wanted-panel__tile").map { Rack::Utils.parse_query(URI(it["href"]).query)["ref"] }

    get market_buyers_path(locale: :en, kind: "goals")
    assert_equal [ ref(@common) ], css_select(".wanted-panel__tile").map { Rack::Utils.parse_query(URI(it["href"]).query)["ref"] }
    assert_select "form:has(button[name=rarity]) input[type=hidden][name=kind][value=goals]"

    get market_buyers_path(locale: :en, kind: "orders", rarity: "common")
    assert_select ".wanted-panel__tile", false
    assert_select ".empty-state", text: /None of your wanted cards matches these filters\./
    assert_select "form:has(button[name=kind]) input[type=hidden][name=rarity][value=common]"

    get market_buyers_path(locale: :en, kind: "nonsense", rarity: "mythic")
    assert_select ".wanted-panel__tile", 2
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
