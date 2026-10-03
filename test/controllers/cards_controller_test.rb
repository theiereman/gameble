require "test_helper"
require_relative "../support/catalog_seeds"

# A card's detail page (CAP-7, story 4.3): every field in the viewer's
# language, the viewer's copies, the sets leading to their tomes, the Steam
# link; open to a visitor; the cards that are not found; the queries of a
# request; no database id on the page.
class CardsControllerTest < ActionDispatch::IntegrationTest
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

  def hold(player, card_season, quantity)
    Game::Holding.create!(player_id: player.id, card_season_id: card_season.id, quantity:)
  end

  # A tome of the fixture season holding portal, beside its publisher set.
  def add_portal_to_a_tome
    set_id = Catalog::Set.insert_all!([ { season_id: catalog_seasons(:one).id, kind: "tome", key: "action-1",
      params: { "genre" => "action", "volume" => 1, "volumes" => 1 } } ], returning: :id).rows.flatten.first
    Catalog::SetMembership.insert_all!([ { set_id:, card_season_id: catalog_card_seasons(:portal_one).id, position: 1 } ])
  end

  # A published season numbered 2 holding portal (gold).
  def publish_season_two_with_portal
    season = seed_published_sets([ [ "tome", "action-1", { "genre" => "action", "volume" => 1, "volumes" => 1 } ] ])
    card_season_id = Catalog::CardSeason.insert_all!([ { card_id: catalog_cards(:portal).id, season_id: season.id, prestige_score: 0.99,
      rating: 99, rarity: 5, dust_tier: 4 } ], returning: :id).rows.flatten.first
    Catalog::SetMembership.insert_all!([ { set_id: Catalog::Set.find_by!(season_id: season.id).id, card_season_id:, position: 1 } ])
    season
  end

  # The fields, as [ label, value ] pairs; the sets joined by " | ".
  def fields
    css_select(".card-detail__fields dt").map do |dt|
      dd = dt.next_element
      items = dd.css("li")
      [ dt.text, items.any? ? items.map { it.text.strip }.join(" | ") : dd.text.strip ]
    end
  end

  def store_link = css_select(".card-detail__store a").sole

  test "a card of the published season: every field, the sets leading to their tomes, the Steam link" do
    catalog_cards(:portal).update_columns(credit: "© 2007 Valve Corporation.\nAll rights reserved.")
    add_portal_to_a_tome

    get card_path(locale: :en, slug: "portal")

    assert_response :success
    assert_select "title", "Portal"
    assert_select ".card-detail h1", "Portal"
    assert_select ".card-detail__face .card.card--large.card--face.card--rarity-amethyst .card__title", "Portal"
    assert_select ".card-detail__description", "A puzzle game of portals."
    assert_equal [ [ "Released", "2007" ], [ "Rarity", "Amethyst" ], [ "Season", "1" ], [ "Sets", "Action · Tome 1 | Valve" ],
      [ "Publisher", "Valve" ], [ "Copyright", "© 2007 Valve Corporation.\nAll rights reserved." ] ], fields
    assert_equal [ [ "Action · Tome 1", "/en/library/tome/action-1" ], [ "Valve", "/en/library/publisher/valve" ] ],
      css_select(".card-detail__sets a").map { [ it.text, it["href"] ] }
    assert_equal "© 2007 Valve Corporation.\nAll rights reserved.", css_select(".card-detail__credit").sole.text
    assert_equal [ "See it on the Steam store", "https://store.example.test/400", "noopener noreferrer external", "_blank" ],
      store_link.then { [ it.text.strip, it["href"], it["rel"], it["target"] ] }
    # The description is never on the face.
    assert_no_match(/portals/, css_select(".card-detail__face").sole.text)
    assert_select ".card-detail__copies", false
    assert_select ".card-detail__owner", false
    assert_select ".status-band > a.button--secondary[href='/en']", "Back to the attic"
  end

  test "in French the title, description, labels and Steam page are French" do
    catalog_cards(:steel_card).update_columns(store_url: "https://store.steampowered.com/app/401/Tin_Soldier/?snr=1_7&l=english")

    get card_path(locale: :fr, slug: "tin-soldier")

    assert_select ".card-detail h1", "Soldat de plomb"
    assert_select "title", "Soldat de plomb"
    assert_equal [ [ "Sortie", "2024" ], [ "Rareté", "Acier" ], [ "Saison", "1" ] ], fields
    assert_equal [ "La voir sur la boutique Steam", "https://store.steampowered.com/app/401/Tin_Soldier/?snr=1_7&l=french" ],
      store_link.then { [ it.text.strip, it["href"] ] }

    get card_path(locale: :fr, slug: "portal")
    assert_select ".card-detail__description", "Un jeu de casse-tête à portails."
    assert_equal "https://store.example.test/400?l=french", store_link["href"]
  end

  test "a card without publisher, credit, description or set leaves those rows out" do
    get card_path(locale: :en, slug: "tin-soldier")

    assert_response :success
    assert_equal [ "Released", "Rarity", "Season" ], fields.map(&:first)
    assert_select ".card-detail__description", false
    assert_select ".card-detail__sets", false
    assert_select ".card-detail__credit", false
  end

  test "a player sees how many copies they hold: two, one, or no line without any" do
    player = accounts_players(:player)
    hold(player, catalog_card_seasons(:portal_one), 2)
    hold(player, catalog_card_seasons(:gold_card_one), 1)
    hold(player, catalog_card_seasons(:steel_card_one), 0)
    sign_in(player)

    get card_path(locale: :en, slug: "portal")
    assert_select ".card-detail__copies", "You hold 2 copies"

    get card_path(locale: :en, slug: "golden-crown")
    assert_select ".card-detail__copies", "You hold 1 copy"

    get card_path(locale: :fr, slug: "golden-crown")
    assert_select ".card-detail__copies", "Tu en détiens 1 exemplaire"

    get card_path(locale: :en, slug: "tin-soldier")
    assert_select ".card-detail__copies", false

    get card_path(locale: :en, slug: "green-hills")
    assert_select ".card-detail__copies", false
  end

  test "a visitor opens the same page, without copies" do
    hold(accounts_players(:player), catalog_card_seasons(:portal_one), 2)

    get card_path(locale: :en, slug: "portal")

    assert_response :success
    assert_select ".card-detail h1", "Portal"
    assert_select ".card-detail__copies", false
  end

  test "an older season by its number: its rarity and dust, its sets without links" do
    publish_season_two_with_portal

    get card_path(locale: :en, slug: "portal")
    assert_select ".card-detail__face .card.card--rarity-gold.card--dust-4"
    assert_equal [ "Gold", "2" ], fields.to_h.values_at("Rarity", "Season")
    assert_equal [ [ "Action · Tome 1", "/en/library/tome/action-1" ] ], css_select(".card-detail__sets a").map { [ it.text, it["href"] ] }

    get card_season_path(locale: :en, slug: "portal", number: 1)
    assert_response :success
    assert_select ".card-detail__face .card.card--rarity-amethyst.card--dust-3"
    assert_equal [ "Amethyst", "1", "Valve" ], fields.to_h.values_at("Rarity", "Season", "Sets")
    assert_select ".card-detail__sets a", false
    assert_select ".card-detail__sets li", "Valve"
  end

  test "an unknown slug, a numeric slug, a card id, a card absent from the season or an unknown season is not found" do
    publish_season_two_with_portal

    [ "/en/cards/nope", "/en/cards/123", "/en/cards/#{catalog_cards(:portal).id}", "/en/cards/tin-soldier",
      "/en/cards/portal/seasons/3", "/en/cards/portal/seasons/0", "/en/cards/portal/seasons/one",
      "/en/cards/portal/seasons/99999999999999999999" ].each do |path|
      get path
      assert_response :not_found, path
    end

    get "/en/cards/tin-soldier/seasons/1"
    assert_response :success
  end

  test "a season number in the query string is ignored: the published season shows" do
    publish_season_two_with_portal

    [ "/en/cards/portal?number[]=1", "/en/cards/portal?number=abc", "/en/cards/portal?number=1" ].each do |path|
      get path
      assert_response :success, path
      assert_equal "2", fields.to_h["Season"], path
    end
  end

  test "with no season published no card is found" do
    catalog_seasons(:one).update_columns(status: "draft", published_at: nil)

    get card_path(locale: :en, slug: "portal")
    assert_response :not_found
  end

  # The test connection keeps its query cache from one request to the next,
  # which a real request never inherits: it is emptied before counting.
  def assert_request_queries(count, &request)
    ActiveRecord::Base.connection.clear_query_cache
    assert_queries_count(count, &request)
  end

  test "a player's request costs four queries, a visitor's two" do
    player = accounts_players(:player)
    hold(player, catalog_card_seasons(:portal_one), 2)
    sign_in(player)

    # Player lookup, card detail, sets, quantities.
    assert_request_queries(4) { get card_path(locale: :en, slug: "portal") }
    assert_response :success
    assert_select ".card-detail__copies", "You hold 2 copies"

    delete session_path(locale: :en)
    # The card detail and its sets.
    assert_request_queries(2) { get card_path(locale: :en, slug: "portal") }
    assert_response :success
  end

  test "no database id reaches the page" do
    player = accounts_players(:player)
    hold(player, catalog_card_seasons(:portal_one), 2)
    sign_in(player)
    ids = [ catalog_cards(:portal).id, catalog_card_seasons(:portal_one).id, catalog_seasons(:one).id, catalog_sets(:valve_one).id,
      catalog_card_texts(:portal_en).id, player.id ]

    get card_path(locale: :en, slug: "portal")

    assert_select ".card-detail [data-id]", false
    html = css_select(".card-detail").sole.to_html
    ids.each do |id|
      next if id < 10 # a season number, a year digit or a count would match

      assert_no_match(/\b#{id}\b/, html, "id #{id} on the page")
    end
    assert_no_match(/\b#{catalog_card_seasons(:portal_one).id}\b/, response.body)
  end
end
