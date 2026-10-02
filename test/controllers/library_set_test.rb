require "test_helper"
require_relative "../support/catalog_seeds"

# One set opened in the library (CAP-6, story 4.2): its heading and owned /
# total, its slots in order, owned faces with their copies and empty slots
# naming their games, for a player and a visitor; the shelf beside it; the
# sets that are not found; the queries of a request.
class LibrarySetTest < ActionDispatch::IntegrationTest
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

  def set_members(season, key)
    set = Catalog::Set.find_by!(season_id: season.id, key:)
    Catalog::SetMembership.where(set_id: set.id).order(:position, :id).pluck(:card_season_id)
  end

  def hold(player, card_season_id, quantity)
    Game::Holding.create!(player_id: player.id, card_season_id:, quantity:)
  end

  def title(card_season_id, locale = "en")
    Catalog::CardText.find_by!(card_id: Catalog::CardSeason.find(card_season_id).card_id, locale:).title
  end

  def year(card_season_id)
    Catalog::CardSeason.find(card_season_id).card.release_date.year
  end

  # The slots in order: [ :owned, title, copies ] or [ :missing, title, year ].
  def slots
    css_select(".open-tome__slots > li").map do |slot|
      if (card = slot.at_css(".card"))
        [ :owned, card.at_css(".card__title").text, slot.at_css(".open-tome__copies")&.text ]
      else
        [ :missing, slot.at_css(".slot__title").text, slot.at_css(".slot__year").text.to_i ]
      end
    end
  end

  def heading = css_select(".open-tome__heading").sole.text
  def progress = css_select(".open-tome__progress [aria-hidden]").sole.text

  test "a player sees their cards' faces with their copies and empty slots naming the rest" do
    season = publish_sets_draft
    player = accounts_players(:player)
    members = set_members(season, "action-1")
    hold(player, members[0], 1)
    hold(player, members[3], 2)
    hold(player, members[24], 1)
    hold(player, members[5], 0)
    sign_in(player)

    get library_set_path(locale: :en, kind: "tome", key: "action-1")

    assert_response :success
    assert_equal "Action · Tome 1 · 2011–2015", heading
    assert_select "title", "Action · Tome 1 · 2011–2015"
    assert_equal "3 / 25", progress
    assert_select ".open-tome__progress .visually-hidden", "3 cards owned out of 25"
    expected = members.each_with_index.map do |id, index|
      case index
      when 0, 24 then [ :owned, title(id), nil ]
      when 3 then [ :owned, title(id), "×2" ]
      else [ :missing, title(id), year(id) ]
      end
    end
    assert_equal expected, slots
    assert_select ".open-tome__slots .card.card--small.card--face", 3
    assert_select ".open-tome__copies[aria-hidden=true] + .visually-hidden", "2 copies"
    assert_select ".slot .slot__missing", { count: 22, text: "Missing card" }
    assert_select ".status-band > a.button--secondary[href='/en']", "Back to the attic"
    assert_select "a.library__back[href=?]", "/en/library?kind=tome", "Back to the shelf"
    assert_select "a[href*='/cards/']", false
  end

  test "a visitor sees the same tome with every slot empty" do
    season = publish_sets_draft
    members = set_members(season, "action-1")
    hold(accounts_players(:player), members.first, 1)

    get library_set_path(locale: :en, kind: "tome", key: "action-1")

    assert_response :success
    assert_equal "0 / 25", progress
    assert_select ".open-tome__slots .card", false
    assert_equal members.map { |id| [ :missing, title(id), year(id) ] }, slots
  end

  test "headings: a tome of one year, a best of year, a publisher" do
    season = publish_sets_draft

    get library_set_path(locale: :en, kind: "tome", key: "action-2")
    assert_equal "Action · Tome 2 · 2015", heading

    get library_set_path(locale: :en, kind: "best_of_year", key: "2015")
    assert_equal "Best rated of 2015", heading
    assert_equal "0 / 10", progress
    assert_equal set_members(season, "2015").map { |id| title(id) }, slots.map(&:second)

    get library_set_path(locale: :fr, kind: "publisher", key: "p")
    assert_equal "P", heading
    assert_equal "0 / 5", progress
  end

  test "in French the titles, heading and words are French" do
    season = publish_sets_draft
    player = accounts_players(:player)
    members = set_members(season, "2011")
    Catalog::CardText.where(card_id: Catalog::CardSeason.find(members.first).card_id, locale: "fr").update_all(title: "La Graine")
    hold(player, members.second, 3)
    sign_in(player)

    get library_set_path(locale: :fr, kind: "best_of_year", key: "2011")

    assert_equal "Les mieux notés de 2011", heading
    assert_select ".open-tome__progress .visually-hidden", "1 carte possédée sur 10"
    assert_equal "La Graine", slots.first.second
    assert_select ".slot__missing", { count: 9, text: "Carte manquante" }
    assert_select ".open-tome__copies + .visually-hidden", "3 exemplaires"
    assert_select "a.library__back", "Retour à l'étagère"
    assert_select ".library__tab[aria-current=page]", "Les mieux notés de l'année"
  end

  test "the spines of the library open their set at the shelf's page, and the open one is current" do
    publish_sets_draft

    get library_path(locale: :en)
    assert_equal [ "/en/library/tome/action-1?page=1", "/en/library/tome/action-2?page=1", "/en/library/tome/action-3?page=1",
      "/en/library/tome/rpg-1?page=1" ], css_select(".shelf a.tome").map { it["href"] }
    assert_select ".shelf .tome[aria-current]", false

    get css_select(".shelf a.tome")[1]["href"]
    assert_response :success
    assert_equal "Action · Tome 2 · 2015", heading
    assert_select ".library__aside .shelf .tome[aria-current=page] .tome__name", "Action · Tome 2"
    assert_select ".library__aside .shelf .tome", 4

    get library_path(locale: :en, kind: "publisher")
    get css_select(".shelf a.tome").first["href"]
    assert_equal "P", heading
    assert_select ".library__aside .shelf .tome[aria-current=page] .tome__name", "P"
  end

  test "the shelf beside the tome is the page asked, the first without one" do
    seed_published_sets((1..60).map { |volume| [ "tome", "action-#{volume}", { "genre" => "action", "volume" => volume, "volumes" => 60 } ] })

    get library_set_path(locale: :en, kind: "tome", key: "action-55", page: 2)
    assert_response :success
    assert_equal "Action · Tome 55", heading
    assert_equal "0 / 0", progress
    assert_select ".shelf .tome[aria-current=page] .tome__name", "Action · Tome 55"
    assert_select ".shelf .tome", 10
    assert_select "a.library__back[href=?]", "/en/library?kind=tome&page=2"

    get library_set_path(locale: :en, kind: "tome", key: "action-55")
    assert_response :success
    assert_select ".shelf .tome", 50
    assert_select ".shelf .tome .tome__name", "Action · Tome 1"
    assert_select ".shelf .tome[aria-current]", false
    assert_select "a.library__back[href=?]", "/en/library?kind=tome"
  end

  test "an unknown kind, an unknown key or a key of another kind is not found" do
    publish_sets_draft

    get "/en/library/nope/action-1"
    assert_response :not_found

    get library_set_path(locale: :en, kind: "tome", key: "action-9")
    assert_response :not_found

    get library_set_path(locale: :en, kind: "publisher", key: "action-1")
    assert_response :not_found

    get library_set_path(locale: :en, kind: "best_of_year", key: "p")
    assert_response :not_found
  end

  test "with no season published no set is found" do
    catalog_seasons(:one).update_columns(status: "draft", published_at: nil)

    get library_set_path(locale: :en, kind: "tome", key: "action-1")
    assert_response :not_found
  end

  test "no set or card-season id reaches the page" do
    season = publish_sets_draft
    player = accounts_players(:player)
    hold(player, set_members(season, "action-1").first, 2)
    sign_in(player)
    ids = Catalog::Set.where(season_id: season.id).ids + Catalog::CardSeason.where(season_id: season.id).ids

    get library_set_path(locale: :en, kind: "tome", key: "action-1")

    assert_select ".library [data-id], .library [id]:not(#library-heading)", false
    html = css_select(".library").sole.to_html
    ids.each do |id|
      assert_no_match(/\b#{id}\b/, html.gsub(/Tome \d+|\d+ \/ \d+|\d+ of \d+|\b(19|20)\d\d\b|×\d+|\d+ cop(y|ies)|seed-\d+-\d+|data-card-art-(width|height)-value="\d+"|width="\d+"|height="\d+"|\?page=\d+/, ""))
    end
  end

  # The test connection keeps its query cache from one request to the next,
  # which a real request never inherits: it is emptied before counting.
  def assert_request_queries(count, &request)
    ActiveRecord::Base.connection.clear_query_cache
    assert_queries_count(count, &request)
  end

  test "a player's request costs nine queries, a visitor's six" do
    season = publish_sets_draft
    player = accounts_players(:player)
    hold(player, set_members(season, "action-1").first, 1)
    sign_in(player)

    # Player lookup, published season, set slots, shelf count, shelf page,
    # totals, progress, card views, quantities.
    assert_request_queries(9) { get library_set_path(locale: :en, kind: "tome", key: "action-1") }
    assert_response :success

    delete session_path(locale: :en)
    # The same without the lookup, the progress and the quantities.
    assert_request_queries(6) { get library_set_path(locale: :en, kind: "tome", key: "action-1") }
    assert_response :success
  end
end
