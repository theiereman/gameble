require "test_helper"
require_relative "../support/catalog_seeds"
require_relative "../support/custom_sets"
require_relative "../support/game_sets"
require_relative "../support/library_requests"
require_relative "../support/steam_sign_in"

# The player's own sets on the collection entry: MES SETS as set progress
# tiles without tiers, closed by the new set tile, the Steam library set's
# tile, and the All sets screen that finds them among the game sets. They stay
# out of EN COURS, COMPLÉTÉS, the hub, the card detail, the grid's set
# filter and every other player's pages.
class LibraryOwnSetsTest < ActionDispatch::IntegrationTest
  include CatalogSeeds
  include CustomSets
  include GameSets
  include LibraryRequests
  include SteamSignIn

  setup do
    @player = accounts_players(:player)
    @season, @cards = published_cards(40)
  end

  def take(count) = @cards.shift(count)

  def card_ids(card_season_ids) = Catalog::CardSeason.where(id: card_season_ids).in_order_of(:id, card_season_ids).pluck(:card_id)

  def own_set(name, members) = create_custom_set(@player, name:, card_ids: card_ids(members))

  def studio(name, size) = insert_set(take(size), { complete: size }, kind: "studio", key: name.parameterize, params: { "studio" => name }, season: @season)

  def mes_sets_tiles = css_select("section.custom-sets ul.custom-sets__tiles > li > a.set-tile")

  def result_tiles = css_select("ul#set-browser-tiles > li > a.set-tile")

  def result_names = result_tiles.map { it.at_css(".set-tile__face--recto .set-tile__name").text }

  def found = css_select("#collection-results-status").sole.text

  test "a custom set of twenty games, seven held, is a MES SETS tile without tiers, the new set tile after it, and stays out of EN COURS" do
    members = take(20)
    custom_set = own_set("Mes favoris", members)
    hold_all(@player, members.first(7))
    sign_in(@player)

    get library_path(locale: :fr)

    assert_select "section.custom-sets > .custom-sets__head > h2#custom-sets-title + p.custom-sets__note", "Visibles par vous seul · 1 / 10"
    tile = mes_sets_tiles.sole
    assert_equal "/fr/library/custom-sets/#{custom_set.token}", tile["href"]
    recto = tile.at_css(".set-tile__face--recto")
    assert_equal [ "Mes favoris", "Set perso · 20 jeux", "7/20" ],
      [ recto.at_css(".set-tile__name").text, recto.at_css(".set-tile__kind").text, recto.at_css(".set-tile__head > .set-tile__count").text.squish ]
    assert_equal 3, recto.css(".set-tile__card").size
    assert_equal "+4", recto.at_css(".set-tile__more").text
    assert_equal "Plus que 13 pour Complet", recto.at_css(".set-tile__next").text.squish
    assert_select tile, ".set-chip--rank, .set-row__tick, .set-tile__track--tiered", false
    assert_not tile["class"].include?("set-tile--closest")
    assert_equal %w[complete], tile.css(".set-tile__node").map { it["class"][/tier-tone--(\w+)/, 1] }
    assert_equal "Mes favoris, set perso, 7 cartes sur 20", tile.at_css("> .visually-hidden").text
    assert_select "section.custom-sets ul.custom-sets__tiles > li:last-child.custom-sets__add > button.new-set-tile"
    assert_select ".custom-sets__unfold", false
    assert_select "[style]", false

    get library_in_progress_path(locale: :fr), headers: { "Turbo-Frame" => "set-entry-in-progress" }
    assert_select ".set-tile", false
    assert_not_includes response.body, "Mes favoris"
  end

  test "a small custom set shows its held game and a silhouette for each missing one; a complete one says so" do
    small = take(3)
    full = take(4)
    own_set("Petit", small)
    own_set("Complet", full)
    hold_all(@player, small.first(1) + full)
    sign_in(@player)

    get library_path(locale: :fr)

    petit, complet = mes_sets_tiles
    assert_equal 1, petit.css(".set-tile__face--recto .set-tile__card").size
    assert_equal %w[common common], petit.css(".set-tile__missing").map { it["class"][/rarity-tone--(\w+)/, 1] }
    assert_equal "Toutes les cartes obtenues", complet.at_css(".set-tile__next").text
    assert_equal "Complet, set perso, 4 cartes sur 4, complet", complet.at_css("> .visually-hidden").text
  end

  test "with no custom set the grid holds only the new set tile; past two sets the phone's unfold button counts the others" do
    sign_in(@player)

    get library_path(locale: :en)
    assert_select ".custom-sets__note", "Visible to you only · 0 / 10"
    assert_select "ul.custom-sets__tiles > li", 1
    assert_select "ul.custom-sets__tiles > li.custom-sets__add > button.new-set-tile"

    2.times { own_set("Set #{it}", take(3)) }
    get library_path(locale: :en)
    assert_select ".custom-sets__unfold", false

    own_set("Set 2", take(3))
    get library_path(locale: :fr)
    assert_select "section.custom-sets[data-controller=set-fold] > ul.custom-sets__tiles[data-set-fold-target=list] + " \
      "button.button--link.custom-sets__unfold[type=button][data-set-fold-target=button][data-action='set-fold#unfold']", "et 1 autre set · Tout voir"

    own_set("Set 3", take(3))
    get library_path(locale: :fr)
    assert_select ".custom-sets__unfold", "et 2 autres sets · Tout voir"
    assert_equal [ "Set 0", "Set 1", "Set 2", "Set 3" ], mes_sets_tiles.map { it.at_css(".set-tile__name").text }
  end

  test "All sets ranks the player's custom sets among the game sets a search finds, prefix first, counted with them, under the My sets kind" do
    studio("Favorite Studio", 3)
    own_set("Mes favoris", take(3))
    favs = own_set("Favs", take(3))
    sign_in(@player)

    get library_sets_path(locale: :fr, q: "fav")

    assert_equal [ "Favorite Studio", "Favs", "Mes favoris" ], result_names
    assert_equal "3 sets affichés.", found
    assert_equal "/fr/library/custom-sets/#{favs.token}", result_tiles[1]["href"]
    assert_equal [ "Set perso · 3 jeux", "0/3" ],
      [ result_tiles[1].at_css(".set-tile__kind").text, result_tiles[1].at_css(".set-tile__head > .set-tile__count").text.squish ]
    assert_select "ul#set-browser-tiles .set-chip--rank", 1

    get library_sets_path(locale: :en, kind: [ "mine" ], q: "fav")
    assert_equal [ "Favs", "Mes favoris" ], result_names
  end

  test "All sets finds a synced Steam library by its name in each locale, never an unsynced one, nor a custom set by a word of its kind line" do
    studio("Steamworks", 3)
    create_library_set(@player, card_ids: card_ids(take(3)))
    own_set("Mes jeux", take(3))
    sign_in(@player)

    get library_sets_path(locale: :fr, q: "biblio")
    assert_equal [ "Ma bibliothèque Steam" ], result_names
    assert_equal "Steam · 3 jeux du catalogue", result_tiles.sole.at_css(".set-tile__kind").text

    get library_sets_path(locale: :en, q: "steam")
    assert_equal [ "Steamworks", "My Steam library" ], result_names

    get library_sets_path(locale: :fr, q: "perso")
    assert_select "p.collection-grid__empty"
    get library_sets_path(locale: :fr, q: "studio")
    assert_equal [ "Steamworks" ], result_names

    Game::CustomSet.where(player_id: @player.id, kind: Game::CustomSet::STEAM_LIBRARY).update_all(synced_at: nil)
    get library_sets_path(locale: :fr, q: "biblio")
    assert_equal "Aucun set affiché.", found
  end

  test "another player's own sets never show: not in a search, not on their profile, nor the owner's on the hub, a card or the grid" do
    members = take(3)
    create_custom_set(accounts_players(:moderator), name: "Jeux secrets", card_ids: card_ids(members))
    own_set("Mes secrets", members)
    hold_all(@player, members.first(1))
    sign_in(@player)

    get library_sets_path(locale: :en, q: "secret")
    assert_equal [ "Mes secrets" ], result_names

    get brother_path(locale: :en, token: accounts_players(:moderator).token)
    assert_not_includes response.body, "Jeux secrets"

    sign_in(accounts_players(:moderator))
    [ brother_path(locale: :en, token: @player.token), brother_collection_path(locale: :en, token: @player.token) ].each do |path|
      get path
      assert_not_includes response.body, "Mes secrets"
    end

    sign_in(@player)
    card = Catalog::CardSeason.find(members.first)
    [ home_path(locale: :en), card_season_path(locale: :en, slug: card.card.slug, number: @season.number),
      library_cards_path(locale: :en, set_kind: "studio") ].each do |path|
      get path
      assert_response :success
      assert_not_includes response.body, "Mes secrets"
    end
  end
end
