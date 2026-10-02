require "test_helper"
require_relative "../support/catalog_seeds"

# The library (CAP-6, story 4.1): the published season's sets by kind, with
# the viewer's owned / total, for a player and a visitor; tabs, pages,
# labels, the empty states and the queries of a request.
class LibraryControllerTest < ActionDispatch::IntegrationTest
  include CatalogSeeds

  setup do
    OmniAuth.config.test_mode = true
  end

  teardown do
    OmniAuth.config.mock_auth.delete(:steam)
    OmniAuth.config.test_mode = false
  end

  def sign_in(player)
    OmniAuth.config.mock_auth[:steam] = OmniAuth::AuthHash.new(provider: "steam", uid: "https://steamcommunity.com/openid/id/#{player.steam_id}")
    post "/auth/steam", params: { origin: "/en" }
    follow_redirect!
    assert_equal player.id, session[:player_id]
  end

  # The shelf as [ name, "owned / total" ] pairs, in order.
  def spines
    css_select(".shelf .tome").map { |tome| [ tome.at_css(".tome__name").text, tome.at_css(".tome__count").text ] }
  end

  def open_tab
    css_select(".library__tab[aria-current=page]").sole.text
  end

  def set_members(season, key)
    set = Catalog::Set.find_by!(season_id: season.id, key:)
    Catalog::SetMembership.where(set_id: set.id).order(:position).pluck(:card_season_id)
  end

  def hold(player, card_season_id, quantity)
    Game::Holding.create!(player_id: player.id, card_season_id:, quantity:)
  end

  test "a player sees the season's tomes with their names and owned / total, cards in several sets counted in each" do
    season = publish_sets_draft
    player = accounts_players(:player)
    first, second, third = set_members(season, "action-1").first(3)
    hold(player, first, 1)
    hold(player, second, 2)
    hold(player, third, 1)
    hold(player, set_members(season, "action-2").first, 0)
    sign_in(player)

    get library_path(locale: :en)

    assert_response :success
    assert_select "h1", "The library of the Brotherhood"
    assert_equal "Tomes", open_tab
    assert_equal [ [ "Action · Tome 1", "3 / 25" ], [ "Action · Tome 2", "0 / 25" ], [ "Action · Tome 3", "0 / 25" ], [ "RPG · Tome 1", "0 / 44" ] ], spines
    assert_select ".tome .visually-hidden", "3 cards owned out of 25"
    assert_select ".status-band > a.button--secondary[href='/en']", "Back to the attic"

    get library_path(locale: :en, kind: "best_of_year")

    owned = [ first, second, third ]
    expected = %w[2015 2012 2011].map do |year|
      members = set_members(season, year)
      [ "Best rated of #{year}", "#{(members & owned).size} / #{members.size}" ]
    end
    assert_equal "Best rated of the year", open_tab
    assert_equal expected, spines
  end

  test "a card in a publisher set and a tome is counted in both" do
    season = publish_sets_draft
    player = accounts_players(:player)
    card = set_members(season, "p").first
    hold(player, card, 1)
    tome = %w[action-1 action-2 action-3].find { |key| set_members(season, key).include?(card) }
    sign_in(player)

    get library_path(locale: :fr, kind: "publisher")

    assert_equal "Éditeurs", open_tab
    assert_equal [ [ "P", "1 / 5" ] ], spines

    get library_path(locale: :fr)

    assert_includes spines, [ "Action · Tome #{tome.last}", "1 / 25" ]
  end

  test "a visitor sees every set at 0 / total" do
    season = publish_sets_draft
    hold(accounts_players(:player), set_members(season, "action-1").first, 1)

    get library_path(locale: :en)

    assert_response :success
    assert_equal [ [ "Action · Tome 1", "0 / 25" ], [ "Action · Tome 2", "0 / 25" ], [ "Action · Tome 3", "0 / 25" ], [ "RPG · Tome 1", "0 / 44" ] ], spines
  end

  test "a player banned since signing in sees the library as a visitor, with no ownership query" do
    season = publish_sets_draft
    player = accounts_players(:player)
    hold(player, set_members(season, "p").first, 1)
    sign_in(player)
    player.update_columns(banned_at: Time.current)

    # The visitor's four, after the lookup that finds the ban.
    assert_no_queries_match(/game_holdings/) do
      assert_request_queries(1 + 4) { get library_path(locale: :en, kind: "publisher") }
    end

    assert_response :success
    assert_equal [ [ "P", "0 / 5" ] ], spines
    assert_nil session[:player_id]
  end

  [ nil, "", "nope", [ "publisher" ] ].each do |kind|
    test "a kind of #{kind.inspect} opens the tomes" do
      publish_sets_draft

      get library_path(locale: :en), params: { kind: }.compact

      assert_response :success
      assert_equal "Tomes", open_tab
      assert_equal 4, spines.size
    end
  end

  test "the tabs lead to each kind, the current one marked" do
    publish_sets_draft

    get library_path(locale: :fr, kind: "best_of_year")

    assert_equal [ [ "Tomes", "/fr/library?kind=tome" ], [ "Éditeurs", "/fr/library?kind=publisher" ],
      [ "Les mieux notés de l'année", "/fr/library?kind=best_of_year" ] ],
      css_select(".library__tabs a").map { |tab| [ tab.text, tab["href"] ] }
    assert_equal "Les mieux notés de l'année", open_tab
  end

  test "a tab with no set of its kind says so" do
    seed_published_sets([ [ "tome", "action-1", { "genre" => "action", "volume" => 1, "volumes" => 1 } ] ])

    get library_path(locale: :en, kind: "publisher")

    assert_response :success
    assert_select ".shelf", false
    assert_select ".library__room p.text-plate", "No publisher has earned a set this season, Brother."
    assert_select ".series-nav", false
  end

  test "labels: a French genre, an unknown genre humanised, a best of year" do
    seed_published_sets([
      [ "tome", "free_to_play-2", { "genre" => "free_to_play", "volume" => 2, "volumes" => 2 } ],
      [ "tome", "xyz-1", { "genre" => "xyz", "volume" => 1, "volumes" => 1 } ],
      [ "best_of_year", "2011", { "year" => 2011 } ]
    ])

    get library_path(locale: :fr)
    assert_equal [ [ "Gratuit · Tome 2", "0 / 0" ], [ "Xyz · Tome 1", "0 / 0" ] ], spines

    get library_path(locale: :fr, kind: "best_of_year")
    assert_equal [ [ "Les mieux notés de 2011", "0 / 0" ] ], spines
  end

  test "tomes are ordered by genre key then volume as a number" do
    seed_published_sets([
      [ "tome", "adventure-1", { "genre" => "adventure", "volume" => 1, "volumes" => 1 } ],
      [ "tome", "action-10", { "genre" => "action", "volume" => 10, "volumes" => 10 } ],
      [ "tome", "action-2", { "genre" => "action", "volume" => 2, "volumes" => 10 } ]
    ])

    get library_path(locale: :en)

    assert_equal [ "Action · Tome 2", "Action · Tome 10", "Adventure · Tome 1" ], spines.map(&:first)
  end

  test "120 tomes come fifty to a page; past the last page the shelf is empty; a page that is no number is the first" do
    seed_published_sets((1..120).map { |volume| [ "tome", "action-#{volume}", { "genre" => "action", "volume" => volume, "volumes" => 120 } ] })

    get library_path(locale: :en)
    assert_equal 50, spines.size
    assert_equal "Action · Tome 1", spines.first.first
    assert_select ".series-nav a[aria-current=page]", "1"
    assert_select ".series-nav a[href='/en/library?page=2']", minimum: 1

    get library_path(locale: :en, page: 2)
    assert_equal 50, spines.size
    assert_equal "Action · Tome 51", spines.first.first

    get library_path(locale: :en, page: 3)
    assert_equal 20, spines.size
    assert_equal "Action · Tome 120", spines.last.first

    get library_path(locale: :en, page: 9)
    assert_response :success
    assert_equal 0, spines.size
    assert_select ".library__room p.text-plate", "This shelf stands empty, Brother. The tomes end on an earlier one."
    assert_select ".series-nav a[href='/en/library?page=3']", minimum: 1

    get library_path(locale: :en, page: "99999999999999999999")
    assert_response :success
    assert_equal 0, spines.size
    assert_select ".library__room p.text-plate", "This shelf stands empty, Brother. The tomes end on an earlier one."

    get library_path(locale: :en, page: "abc")
    assert_response :success
    assert_equal "Action · Tome 1", spines.first.first
    assert_equal 50, spines.size
  end

  test "the page links speak the Brotherhood's words in the page's locale" do
    seed_published_sets((1..60).map { |volume| [ "tome", "action-#{volume}", { "genre" => "action", "volume" => volume, "volumes" => 60 } ] })

    get library_path(locale: :fr)
    assert_select "nav.series-nav[aria-label=?]", "Les étagères"
    assert_select ".series-nav a[aria-label=?][href='/fr/library?page=2']", "L'étagère suivante"

    get library_path(locale: :en, page: 2)
    assert_select "nav.series-nav[aria-label=?]", "The shelves"
    assert_select ".series-nav a[aria-label=?][href='/en/library?page=1']", "The previous shelf"
  end

  test "the owned count is read out with its plural, French singular for 0 and 1" do
    season = publish_sets_draft
    player = accounts_players(:player)
    hold(player, set_members(season, "action-1").first, 1)
    sign_in(player)

    get library_path(locale: :fr)
    assert_equal [ "1 carte possédée sur 25", "0 carte possédée sur 25" ], css_select(".tome .visually-hidden").first(2).map(&:text)

    get library_path(locale: :en)
    assert_equal [ "1 card owned out of 25", "0 cards owned out of 25" ], css_select(".tome .visually-hidden").first(2).map(&:text)
  end

  test "with no season published the library says so" do
    catalog_seasons(:one).update_columns(status: "draft", published_at: nil)

    get library_path(locale: :en)

    assert_response :success
    assert_select ".library__room p.text-plate", "The shelves are bare, Brother: the Brotherhood has published no season of cards yet."
    assert_select ".library__tabs", false
  end

  test "no set or card-season id reaches the page" do
    season = publish_sets_draft
    ids = Catalog::Set.where(season_id: season.id).ids + Catalog::CardSeason.where(season_id: season.id).ids

    get library_path(locale: :en)

    assert_select ".library [data-id], .library [id]:not(#library-heading)", false
    shelf = css_select(".library").sole.to_html
    ids.each { |id| assert_no_match(/\b#{id}\b/, shelf.gsub(/Tome \d+|\d+ \/ \d+|\d+ of \d+/, "")) }
  end

  # The test connection keeps its query cache from one request to the next,
  # which a real request never inherits: it is emptied before counting.
  def assert_request_queries(count, &request)
    ActiveRecord::Base.connection.clear_query_cache
    assert_queries_count(count, &request)
  end

  test "a player's request costs six queries, a visitor's four" do
    publish_sets_draft
    sign_in(accounts_players(:player))

    # Player lookup, published season, Pagy count, set page, totals, progress.
    assert_request_queries(6) { get library_path(locale: :en) }

    delete session_path(locale: :en)
    # The same without the lookup and the progress.
    assert_request_queries(4) { get library_path(locale: :en) }
  end
end
