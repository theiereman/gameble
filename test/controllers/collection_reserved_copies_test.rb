require "test_helper"
require_relative "../support/custom_sets"
require_relative "../support/library_requests"
require_relative "../support/market"
require_relative "../support/market_listings"
require_relative "../support/steam_sign_in"

# A copy on sale or in a pending trade stays owned but is set apart: its
# reasons under the owner's tile, out of the duplicates, in the detail's copies.
class CollectionReservedCopiesTest < ActionDispatch::IntegrationTest
  include CustomSets
  include LibraryRequests
  include MarketListings
  include MarketSettings
  include SteamSignIn

  setup do
    open_market!
    @player = accounts_players(:player)
    @portal = catalog_card_seasons(:portal_one)
    hold(@player, @portal.id, 3, reserved: 2)
    hold(@player, catalog_card_seasons(:common_card_one).id, 2)
    @listing = listing!(seller: @player, card_season: @portal)
  end

  def tile(title) = css_select(".collection-slot").find { it.at_css(".card__title")&.text == title }

  def reasons(title) = tile(title).css(".collection-slot__reserved .collection-slot__reason").map { it.text.squish }

  def titles = css_select(".collection-slot .card__title").map(&:text)

  def report
    css_select(".report--panel .report__row").first(2).to_h { [ it.at_css("dt").text.strip, it.at_css("dd").text ] }
  end

  def add_puzzle_set
    set_id = Catalog::Set.insert_all!([ { season_id: catalog_seasons(:one).id, kind: "theme", key: "puzzle", params: { "theme" => "puzzle" } } ],
      returning: :id).rows.flatten.sole
    Catalog::SetMembership.insert_all!([ [ :portal_one, 1 ], [ :common_card_one, 2 ] ].map do |card_season, position|
      { set_id:, card_season_id: catalog_card_seasons(card_season).id, position: }
    end)
  end

  test "the owner's tile keeps its copies and says why some are set apart; the report counts the free spares only" do
    sign_in(@player)

    get library_cards_path(locale: :en)

    assert_response :success
    assert_equal "x3", tile("Portal").at_css(".collection-slot__copies").text
    assert_equal [ "1 on sale", "1 in a trade" ], reasons("Portal")
    assert_empty reasons("Tin Soldier")
    assert_equal({ "Total cards" => "5", "Duplicates" => "1" }, report)
    assert_select ".report--fold summary .report__line", "5 cards · 1 duplicate"
  end

  test "the duplicates filter keeps the games with two free copies" do
    sign_in(@player)

    get library_cards_path(locale: :en, state: %w[duplicates])

    assert_equal [ "Tin Soldier" ], titles
  end

  test "in French, the reasons and the detail's copies" do
    sign_in(@player)

    get library_cards_path(locale: :fr)
    assert_equal [ "1 en vente", "1 en échange" ], reasons("Portal")

    get card_season_path(locale: :fr, slug: "portal", number: 1)
    assert_select ".card-detail__copies", "3 exemplaires, dont 1 en vente et 1 en échange"
  end

  test "the card detail names the copies set apart; with none it reads as before" do
    sign_in(@player)

    get card_season_path(locale: :en, slug: "portal", number: 1)
    assert_select ".card-detail__copies", "3 copies, including 1 on sale and 1 in a trade"

    get card_season_path(locale: :en, slug: "tin-soldier", number: 1)
    assert_select ".card-detail__copies", "2 copies"
  end

  test "a cancelled listing takes its tag away and gives its copy back to the spares" do
    assert Game::Market::CancelListing.new.call(player: @player, listing_id: @listing.id).success?
    sign_in(@player)

    get library_cards_path(locale: :en)

    assert_equal [ "1 in a trade" ], reasons("Portal")
    assert_equal({ "Total cards" => "5", "Duplicates" => "2" }, report)
  end

  test "another player's grid and album show no reason, and their duplicates count the free copies" do
    add_puzzle_set
    sign_in(accounts_players(:moderator))

    get brother_collection_path(locale: :en, token: @player.token)
    assert_response :success
    assert_select ".collection-slot__reserved", false
    assert_equal "x3", tile("Portal").at_css(".collection-slot__copies").text
    assert_equal({ "Total cards" => "5", "Duplicates" => "1" }, report)

    get brother_collection_path(locale: :en, token: @player.token, state: %w[duplicates])
    assert_equal [ "Tin Soldier" ], titles

    get brother_set_path(locale: :en, token: @player.token, kind: "theme", key: "puzzle")
    assert_response :success
    assert_select ".collection-slot__reserved", false
  end

  test "the owner's set album shows the reasons under the card" do
    add_puzzle_set
    sign_in(@player)

    get library_set_path(locale: :en, kind: "theme", key: "puzzle")

    assert_response :success
    assert_equal [ "1 on sale", "1 in a trade" ], reasons("Portal")
    assert_empty reasons("Tin Soldier")
  end

  test "an only copy on sale keeps its tile owned, with its reason" do
    blue = catalog_card_seasons(:rare_card_one)
    hold(@player, blue.id, 1, reserved: 1)
    listing!(seller: @player, card_season: blue)
    sign_in(@player)

    get library_cards_path(locale: :en)

    assert_equal "x1", tile("Blue Depths").at_css(".collection-slot__copies").text
    assert_equal [ "1 on sale" ], reasons("Blue Depths")
  end

  test "the owner's custom set album shows the reasons under the card" do
    custom_set = create_custom_set(@player, card_ids: fixture_card_ids.first(4))
    sign_in(@player)

    get custom_set_path(locale: :en, token: custom_set.token)

    assert_response :success
    assert_equal [ "1 on sale", "1 in a trade" ], reasons("Portal")
  end

  test "a grid page appended by a stream carries the reasons" do
    sign_in(@player)

    get library_cards_path(locale: :en), headers: { "Accept" => "text/vnd.turbo-stream.html" }

    assert_equal Mime[:turbo_stream], response.media_type
    appended = css_select("turbo-stream[action=append][target=collection-slots] template").sole
    assert_includes appended.css(".collection-slot__reason").map { it.text.squish }, "1 on sale"
  end
end
