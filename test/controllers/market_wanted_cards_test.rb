require "test_helper"
require_relative "../support/game_sets"
require_relative "../support/holdings"
require_relative "../support/market"
require_relative "../support/market_listings"
require_relative "../support/steam_sign_in"

# The market tells a signed-in player, on each listing, whether they own the card, and marks the cards their
# goals miss; a chip keeps only those, with their count.
class MarketWantedCardsTest < ActionDispatch::IntegrationTest
  include GameSets
  include Holdings
  include MarketListings
  include MarketSettings
  include SteamSignIn

  setup do
    open_market!(first_opened_at: 1.day.ago)
    @player = accounts_players(:player)
    seller = accounts_players(:moderator)
    @wanted = catalog_card_seasons(:common_card_one)
    @owned = catalog_card_seasons(:rare_card_one)
    @other = catalog_card_seasons(:portal_one)
    insert_set([ @wanted.id, @owned.id, *unheld_cards(1) ], { complete: 3 }, key: "roguelike", params: { "theme" => "roguelike" })
    hold(@player, @owned.id, 2)
    [ @wanted, @owned, @other ].each_with_index { |card, index| listing!(seller:, card_season: card, hours: 12 + index) }
  end

  def aim = Game::AddGoal.new.call(player: @player, kind: "theme", key: "roguelike").value!

  def marks = css_select(".listing-tile__mark").map { it.text.strip }

  test "each tile says whether the player owns the card, and a missing card of a goal is wanted, with its goal's bookmark" do
    aim
    sign_in(@player)

    get market_path(locale: :fr)

    assert_response :success
    assert_equal [ "Voulue", "Possédée ×2", "Non possédée" ], marks
    assert_select ".listing-tile__link--wanted", 1
    assert_select ".listing-tile__link--wanted .goal-bookmark", 1
    assert_select ".listing-tile .goal-bookmark", 1
    assert_select ".listing-tile__link[aria-label$='manque à vos objectifs']", 1
    assert_select ".listing-tile__link[aria-label$='2 exemplaires dans votre collection']", 1
    assert_select ".market-filters__wanted", /Cartes voulues\s+1/
  end

  test "the wanted chip keeps the listings of the cards the goals miss, and the sort keeps it" do
    aim
    sign_in(@player)

    get market_path(locale: :en, wanted: "1")

    assert_equal [ "Wanted" ], marks
    assert_select ".market-filters__wanted input[checked]"
    assert_select "a[href*='wanted=1']"
  end

  test "without a goal the tiles still tell what the player owns, without the chip" do
    sign_in(@player)

    get market_path(locale: :en)

    assert_equal [ "Not owned", "Owned ×2", "Not owned" ], marks
    assert_select ".market-filters__wanted", false
  end

  test "a visitor sees neither marks nor chip" do
    get market_path(locale: :en)

    assert_empty marks
    assert_select ".listing-tile", 3
    assert_select ".market-filters__wanted", false
  end
end
