require "test_helper"
require_relative "../support/holdings"
require_relative "../support/market"
require_relative "../support/market_auctions"
require_relative "../support/market_orders"
require_relative "../support/steam_sign_in"

# A card detail tells a player holding a free copy that other players want it, with the best order a copy of theirs can serve,
# above CONFIER and METTRE EN VENTE.
class CardWantedLineTest < ActionDispatch::IntegrationTest
  include Holdings
  include MarketAuctions
  include MarketOrders
  include MarketSettings
  include SteamSignIn

  setup do
    Game::Market::Settings.delete_all
    open_market!(first_opened_at: 1.day.ago)
    @player = accounts_players(:player)
    @portal = catalog_card_seasons(:portal_one)
    hold(@player, @portal.id, 1)
  end

  def want_by_goal(*players)
    Game::Market::Wanted.insert_all(players.map { { player_id: it.id, card_id: @portal.card_id, reason: "goal", rarities: nil } })
  end

  test "the line counts the seekers and names the best order, above the market buttons" do
    buyer = accounts_players(:administrator)
    fund!(buyer, 300)
    order!(buyer, @portal, 300)
    Game::Market::RebuildWanted.new.call(player: buyer).value!
    want_by_goal(accounts_players(:moderator))
    sign_in(@player)

    get card_path(locale: :fr, slug: "portal")

    assert_select ".card-detail__market > .card-detail__wanted:first-child" do
      assert_select ".wanted-badge", "DEMANDÉE"
      assert_select ".card-detail__wanted-line", /2 joueurs la veulent · meilleur ordre\s+300/
      assert_select ".card-detail__wanted-order .picoin-amount__figure", "300"
    end
  end

  test "without an order the line says there is none" do
    want_by_goal(accounts_players(:moderator))
    sign_in(@player)

    get card_path(locale: :en, slug: "portal")

    assert_select ".card-detail__wanted-line", "1 player wants it · no buy order"
  end

  test "the line counts the seekers of the edition shown, not of another edition held" do
    season = Catalog::Season.create!(number: 2)
    rare_portal = Catalog::CardSeason.create!(card_id: @portal.card_id, season:, prestige_score: 0.9, rating: 95.5, rarity: :rare, number: 4)
    hold(@player, rare_portal.id, 1)
    want_by_goal(accounts_players(:moderator))
    Game::Market::Wanted.insert_all([ { player_id: accounts_players(:administrator).id, card_id: @portal.card_id, reason: "order", rarities: [ 3 ] } ])
    sign_in(@player)

    get card_season_path(locale: :en, slug: "portal", number: 1)

    assert_select ".card-detail__wanted-line", "1 player wants it · no buy order"
  end

  test "nobody wanting the card draws no line" do
    sign_in(@player)

    get card_path(locale: :en, slug: "portal")

    assert_select ".card-detail__market a.button--secondary", 2
    assert_select ".card-detail__wanted", false
  end
end
