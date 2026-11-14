require "test_helper"
require_relative "../../support/holdings"
require_relative "../../support/market"
require_relative "../../support/market_listings"

class Game::ReservedCopiesTest < ActiveSupport::TestCase
  include Holdings
  include MarketListings
  include MarketSettings

  setup do
    open_market!
    @player = accounts_players(:player)
    @portal = catalog_cards(:portal).id
    @portal_one = catalog_card_seasons(:portal_one)
  end

  def on_sale(card_season, copies = 1, seller: @player)
    copies.times { listing!(seller:, card_season:) }
  end

  def second_edition(name)
    season = Catalog::Season.create!(status: :published, number: 2, published_at: Time.current)
    one = catalog_card_seasons(name)
    Catalog::CardSeason.insert_all!([ { card_id: one.card_id, season_id: season.id, prestige_score: one.prestige_score, rating: one.rating,
      rarity: one.rarity, number: one.number } ], returning: :id).rows.flatten.sole
  end

  def set_apart(on_sale:, in_trade:) = Game::ReservedCopies::Reserved.new(on_sale:, in_trade:)

  def reserved(card_ids = [ @portal ]) = Game::ReservedCopies.call(@player, card_ids:)

  test "a spare on sale: one copy on sale, one duplicate fewer" do
    hold(@player, @portal_one.id, 2, reserved: 1)
    on_sale(@portal_one)

    assert_equal({ @portal => set_apart(on_sale: 1, in_trade: 0) }, reserved)
    assert_equal 0, Game::ReservedCopies.duplicates(@player)
  end

  test "the only copy on sale is still reserved, and no duplicate" do
    hold(@player, @portal_one.id, 1, reserved: 1)
    on_sale(@portal_one)

    assert_equal({ @portal => set_apart(on_sale: 1, in_trade: 0) }, reserved)
    assert_equal 0, Game::ReservedCopies.duplicates(@player)
  end

  test "a copy on sale and one in a trade: what no listing explains is in a trade" do
    hold(@player, @portal_one.id, 3, reserved: 2)
    on_sale(@portal_one)

    assert_equal({ @portal => set_apart(on_sale: 1, in_trade: 1) }, reserved)
    assert_equal 0, Game::ReservedCopies.duplicates(@player)
  end

  test "copies spread over editions add up per game; the free copies make the duplicates" do
    hold(@player, @portal_one.id, 2, reserved: 1)
    hold(@player, second_edition(:portal_one), 1)
    on_sale(@portal_one)

    assert_equal({ @portal => set_apart(on_sale: 1, in_trade: 0) }, reserved)
    assert_equal 1, Game::ReservedCopies.duplicates(@player)
  end

  test "a listing no longer open is no copy on sale; another player's listings never count" do
    hold(@player, @portal_one.id, 2, reserved: 1)
    listing!(seller: @player, card_season: @portal_one, status: "cancelled")
    hold(accounts_players(:moderator), @portal_one.id, 1, reserved: 1)
    on_sale(@portal_one, seller: accounts_players(:moderator))

    assert_equal({ @portal => set_apart(on_sale: 0, in_trade: 1) }, reserved)
  end

  test "a card with nothing reserved is absent; only the cards asked are read" do
    hold(@player, @portal_one.id, 2)
    hold(@player, catalog_card_seasons(:rare_card_one).id, 1, reserved: 1)

    assert_equal({}, reserved)
    assert_equal [ catalog_cards(:rare_card).id ], reserved([ @portal, catalog_cards(:rare_card).id ]).keys
  end

  test "with nothing reserved the duplicates are every copy past a game's first" do
    hold(@player, @portal_one.id, 3)
    hold(@player, second_edition(:portal_one), 1)
    hold(@player, catalog_card_seasons(:rare_card_one).id, 1)
    hold(@player, catalog_card_seasons(:common_card_one).id, 0)

    assert_equal 3, Game::ReservedCopies.duplicates(@player)
  end

  test "a visitor or no card asked costs no query" do
    assert_queries_count(0) do
      assert_equal({}, Game::ReservedCopies.call(nil, card_ids: [ @portal ]))
      assert_equal({}, Game::ReservedCopies.call(@player, card_ids: []))
      assert_equal 0, Game::ReservedCopies.duplicates(nil)
    end
  end
end
