require "test_helper"
require_relative "../support/catalog_seeds"
require_relative "../support/library_requests"
require_relative "../support/game_packs"
require_relative "../support/game_sets"
require_relative "../support/steam_sign_in"

# A card's detail page ("FICHE DE LA CARTE"): every fact in the viewer's
# language, the viewer's copies, the sets leading to their grids, the Steam
# link; open to a visitor; the share link, the page's own address, for
# every card; what it browses (an opened pack, the collection grid as
# shown, a set), its ◀ ▶ and position line, the card's face whether held
# or not, the phone's way back to it; the cards that are not found; the
# queries of a request; no database id on the page. Most tests read the
# detail as a signed-in viewer: a visitor on the card's own page gets the
# public card page instead, which, with the preview tags, is
# covered in card_preview_tags_test.rb.
class CardsControllerTest < ActionDispatch::IntegrationTest
  include CatalogSeeds
  include LibraryRequests
  include GamePacks
  include GameSets
  include SteamSignIn

  setup do
    # A PUBLIC_URL exported in the shell would replace the request's base.
    @public_url = Rails.configuration.x.public_url
    Rails.configuration.x.public_url = nil
  end

  teardown do
    Rails.configuration.x.public_url = @public_url
  end

  # A theme set of the fixture season holding, in slot order, tin-soldier,
  # portal and blue-depths (positions 2, 1, 3 by id), beside portal's
  # studio set.
  def add_a_theme_set
    set_id = Catalog::Set.insert_all!([ { season_id: catalog_seasons(:one).id, kind: "theme", key: "puzzle",
      params: { "theme" => "puzzle" } } ], returning: :id).rows.flatten.first
    Catalog::SetMembership.insert_all!([ [ :portal_one, 2 ], [ :common_card_one, 1 ], [ :rare_card_one, 3 ] ].map do |card_season, position|
      { set_id:, card_season_id: catalog_card_seasons(card_season).id, position: }
    end)
  end

  # A published season numbered 2 holding portal (legendary).
  def publish_season_two_with_portal
    season = seed_published_sets([ [ "theme", "puzzle", { "theme" => "puzzle" } ] ])
    card_season_id = Catalog::CardSeason.insert_all!([ { card_id: catalog_cards(:portal).id, season_id: season.id, prestige_score: 0.99,
      rating: 99, rarity: 5, number: 1 } ], returning: :id).rows.flatten.first
    Catalog::SetMembership.insert_all!([ { set_id: Catalog::Set.find_by!(season_id: season.id).id, card_season_id:, position: 1 } ])
    season
  end

  # Gives a card-season of the fixture season a main theme, as a season
  # published with themes would have.
  def with_main_theme(card_season, theme)
    Catalog::CardSeason.where(id: catalog_card_seasons(card_season).id).update_all(main_theme: theme)
  end

  def in_theme(slug, locale: :en, number: 1) = card_season_path(locale:, slug:, number:, set_kind: "theme", set_key: "puzzle")

  # The fact rows, as [ label, value ] pairs; the sets joined by " | ".
  def facts
    css_select(".card-detail__fact").map do |row|
      dd = row.at_css("dd")
      items = dd.css("li")
      [ row.at_css("dt").text, items.any? ? items.map { it.text.strip }.join(" | ") : dd.text.squish ]
    end
  end

  def store_link = css_select(".card-detail__actions a.card-detail__store").sole

  # A viewer who holds nothing: the detail, not the public page.
  def sign_in_viewer = sign_in(accounts_players(:moderator))

  # ◀ and ▶: [ tag, href or "disabled" ].
  def navs
    css_select(".card-detail__nav").map { [ it.name, it.name == "a" ? it["href"] : (it["disabled"] && "disabled") ] }
  end

  def position = css_select(".card-detail__position").sole.text

  test "a card of the published season: the bracketed panel, its face, every fact, the sets leading to their grids, no ownership notice, the Steam link under the panel" do
    add_a_theme_set
    with_main_theme(:portal_one, "puzzle")
    sign_in_viewer

    get card_path(locale: :en, slug: "portal")

    assert_response :success
    assert_select "title", "Portal — Epic"
    assert_select "main > turbo-frame#card-detail[target=_top] > article.card-detail[aria-labelledby=card-detail-heading] > .card-detail__panel.panel.panel--brackets"
    assert_select "article.card-detail.panel", false
    assert_select "article.card-detail > .card-detail__panel + .card-detail__actions"
    assert_select ".card-detail__panel .card-detail__actions", false
    assert_select ".card-detail__panel .button", false
    assert_select ".card-detail__kicker", "Card file"
    assert_select ".card-detail__number", "S1 · #4"
    assert_select ".card-detail h1#card-detail-heading", "Portal"
    assert_select ".card-detail__card .card.card--l.card--rarity-epic .card__title", "Portal"
    assert_select "[style]", 0
    assert_select ".card-detail__description", "A puzzle game of portals."
    assert_equal [ [ "Publisher", "Valve" ], [ "Rarity", "Epic" ], [ "Genre", "Puzzle" ], [ "Year", "2007" ], [ "Season", "Season 1" ],
      fixture_pioneer, [ "Sets", "Puzzle | Valve" ], [ "Copies", "None" ], [ "Editions", "None" ] ], facts
    assert_select ".card-detail__rarity.card-detail__rarity--epic svg.card-detail__rarity-icon[aria-hidden=true]"
    assert_equal [ [ "Puzzle", "/en/library/theme/puzzle" ], [ "Valve", "/en/library/studio/valve" ] ],
      css_select(".card-detail__sets a").map { [ it.text, it["href"] ] }
    assert_select ".card-detail__notice", false
    assert_no_match(/not affiliated|belong to their/i, response.body)
    assert_equal [ "See on Steam (new tab)", "https://store.example.test/400", "noopener noreferrer external", "_blank" ],
      store_link.then { [ it.text.squish, it["href"], it["rel"], it["target"] ] }
    assert_includes store_link["class"], "button--secondary"
    assert_select ".card-detail .button--primary", 0
    assert_select ".card-detail__actions > .card-detail__card-links:only-child"
    # The description is never on the face.
    assert_no_match(/portals/, css_select(".card-detail__card").sole.text)
    assert_no_match(/collection of/i, response.body)
    assert_select ".top-bar__start > a.button--secondary[href='/en']", "Bridge"
  end

  test "a card's franchise and studio sets are named and lead to their grids, in English and French" do
    season = publish_franchises_and_studios_draft
    sign_in_viewer

    get card_path(locale: :en, slug: "seed-#{season.number}-0")
    assert_equal [ [ "RPG", "/en/library/theme/rpg" ], [ "Tom Clancy", "/en/library/franchise/tom-clancy" ] ],
      css_select(".card-detail__sets a").map { [ it.text, it["href"] ] }

    get card_path(locale: :fr, slug: "seed-#{season.number}-3")
    assert_equal [ [ "RPG", "/fr/library/theme/rpg" ], [ "CAPCOM", "/fr/library/studio/capcom" ] ],
      css_select(".card-detail__sets a").map { [ it.text, it["href"] ] }
  end

  test "a card's hall of fame sets are named in their fixed order and lead to their grids, in English and French" do
    season = publish_hall_of_fame_draft
    sign_in_viewer

    get card_path(locale: :en, slug: "seed-#{season.number}-5")
    assert_equal [ [ "RPG", "/en/library/theme/rpg" ], [ "The Untouchables", "/en/library/hall_of_fame/intouchables" ],
      [ "The Phenomena", "/en/library/hall_of_fame/phenomenes" ] ], css_select(".card-detail__sets a").map { [ it.text, it["href"] ] }

    get card_path(locale: :fr, slug: "seed-#{season.number}-1")
    assert_equal [ [ "RPG", "/fr/library/theme/rpg" ], [ "Les Pépites", "/fr/library/hall_of_fame/pepites" ] ],
      css_select(".card-detail__sets a").map { [ it.text, it["href"] ] }
  end

  test "in French every fact, the title, description and Steam page are French" do
    add_a_theme_set
    with_main_theme(:common_card_one, "horror")
    with_main_theme(:portal_one, "puzzle")
    sign_in_viewer
    catalog_cards(:common_card).update_columns(store_url: "https://store.steampowered.com/app/401/Tin_Soldier/?snr=1_7&l=english")

    get card_path(locale: :fr, slug: "tin-soldier")

    assert_select ".card-detail h1", "Soldat de plomb"
    assert_select "title", "Soldat de plomb — Commune"
    assert_select ".card-detail__kicker", "Fiche de la carte"
    assert_equal [ [ "Rareté", "Commune" ], [ "Genre", "Horreur" ], [ "Année", "2024" ], [ "Saison", "Saison 1" ], fixture_pioneer(locale: :fr), [ "Sets", "Réflexion" ], [ "Exemplaires", "Aucun" ], [ "Éditions", "Aucune" ] ], facts
    assert_equal [ "Voir sur Steam (nouvel onglet)", "https://store.steampowered.com/app/401/Tin_Soldier/?snr=1_7&l=french" ],
      store_link.then { [ it.text.squish, it["href"] ] }
    assert_equal [ "Carte précédente", "Carte suivante" ], css_select(".card-detail__nav").map { it["aria-label"] }
    assert_equal "S1 · #1 · 1 / 3 · glissez pour parcourir", position

    get card_path(locale: :fr, slug: "portal")
    assert_select ".card-detail__description", "Un jeu de casse-tête à portails."
    assert_equal "https://store.example.test/400?l=french", store_link["href"]
    assert_equal [ "Éditeur", "Rareté", "Genre", "Année", "Saison", "Pionnier", "Sets", "Exemplaires", "Éditions" ], facts.map(&:first)
  end

  test "a card without publisher, description, genre or set leaves those rows out, without ◀ ▶ or position line" do
    sign_in_viewer
    get card_path(locale: :en, slug: "tin-soldier")

    assert_response :success
    assert_equal [ "Rarity", "Year", "Season", "Pioneer", "Copies", "Editions" ], facts.map(&:first)
    assert_select ".card-detail__description", false
    assert_select ".card-detail__sets", false
    assert_select ".card-detail__nav", false
    assert_select ".card-detail__position", false
    assert_select ".top-bar__phone-back", false
  end

  test "a card-season with a review count shows its Steam reviews last, in each locale's number format; the visitor's page and the face do not" do
    Catalog::CardSeason.where(id: catalog_card_seasons(:portal_one).id).update_all(review_count: 12_345, rating: 93.4)

    get card_path(locale: :en, slug: "portal")
    assert_select ".public-card"
    assert_no_match(/Steam reviews|positive ·/, response.body)

    sign_in_viewer

    get card_path(locale: :en, slug: "portal")
    assert_equal [ "Steam reviews", "93% positive · 12,345 reviews" ], facts.last
    assert_select ".card-detail .card", text: /12,345|93%/, count: 0

    get card_path(locale: :fr, slug: "portal")
    assert_equal [ "Avis Steam", "93 % positifs · 12 345 avis" ], facts.last
    assert_includes response.body, "93\u00A0% positifs · 12\u00A0345 avis"

    Catalog::CardSeason.where(id: catalog_card_seasons(:portal_one).id).update_all(review_count: 1, rating: 99.8)
    get card_path(locale: :en, slug: "portal")
    assert_equal [ "Steam reviews", "99% positive · 1 review" ], facts.last
  end

  test "a player sees their copies: two, one, or None; in French too" do
    player = accounts_players(:player)
    hold(player, catalog_card_seasons(:portal_one).id, 2)
    hold(player, catalog_card_seasons(:legendary_card_one).id, 1)
    hold(player, catalog_card_seasons(:common_card_one).id, 0)
    sign_in(player)

    get card_path(locale: :en, slug: "portal")
    assert_equal [ [ "Copies", "2 copies" ], [ "Editions", "Epic: S1" ] ], facts.last(2)

    get card_path(locale: :en, slug: "golden-crown")
    assert_equal [ [ "Copies", "1 copy" ], [ "Editions", "Legendary: S1" ] ], facts.last(2)

    get card_path(locale: :fr, slug: "golden-crown")
    assert_equal [ [ "Exemplaires", "1 exemplaire" ], [ "Éditions", "Légendaire : S1" ] ], facts.last(2)

    get card_path(locale: :en, slug: "tin-soldier")
    assert_equal [ [ "Copies", "None" ], [ "Editions", "None" ] ], facts.last(2)

    get card_path(locale: :fr, slug: "green-hills")
    assert_equal [ [ "Exemplaires", "Aucun" ], [ "Éditions", "Aucune" ] ], facts.last(2)
  end

  test "a visitor on the card's own page gets the public card page: the card at card-xl, no copies, no panel, no way back to the bridge" do
    hold(accounts_players(:player), catalog_card_seasons(:portal_one).id, 2)

    get card_path(locale: :en, slug: "portal")

    assert_response :success
    assert_select ".public-card h1", "Portal"
    assert_select ".public-card .card.card--xl.card--rarity-epic .card__title", "Portal"
    assert_select ".public-card__publisher", "Valve"
    assert_select ".public-card__line", "Epic · 2007 · S1 · #4"
    assert_select ".public-card__description", "A puzzle game of portals."
    assert_equal [ "https://store.example.test/400", "_blank" ], css_select("a.public-card__store").sole.then { [ it["href"], it["target"] ] }
    assert_select ".card-detail", false
    assert_select ".card-detail__copies", false
    assert_select ".top-bar__start > a.button--secondary", false
    assert_select "a.top-bar__brand[href=?][data-controller=wordmark-shine] svg.top-bar__wordmark g.wordmark-sweep__frames", "/en"
    assert_select "nav.tab-bar", false
    assert_select "body.is-public-page"
    assert_select ".top-bar__end a[href^='/en/sign-in']"
  end

  test "the public card page's only way into the game is the Steam sign-in: its only link to the landing is the wordmark" do
    get card_path(locale: :en, slug: "portal")

    assert_select ".public-card a[href=?]", "/en", false
    assert_select ".public-card__pitch a[href^='/en/sign-in']"
  end

  test "the card's own page browses its first set, themes first: ◀ ▶ carry that set, the position line, the phone's way back to its grid" do
    add_a_theme_set
    sign_in_viewer

    get card_path(locale: :en, slug: "portal")

    assert_equal [ [ "a", in_theme("tin-soldier") ], [ "a", in_theme("blue-depths") ] ], navs
    assert_equal [ "Previous card", "Next card" ], css_select(".card-detail__nav").map { it["aria-label"] }
    css_select("a.card-detail__nav").each do |link|
      assert_equal [ "card-detail", "replace", "false" ], [ link["data-turbo-frame"], link["data-turbo-action"], link["data-turbo-prefetch"] ]
    end
    assert_equal "S1 · #4 · 2 / 3 · swipe to browse", position
    back = css_select(".top-bar__start.top-bar__start--phone-back > a.top-bar__phone-back").sole
    assert_equal [ "/en/library/theme/puzzle", "history-back", "Grid" ], [ back["href"], back["data-controller"], back.text.squish ]
    assert_equal "/en/library/theme/puzzle", css_select(".card-detail").sole["data-sub-view-back-value"]
    # The bridge stays, for the desktop.
    assert_select ".top-bar__start > a.button--secondary[href='/en']", "Bridge"
    # Without a set in the query, the face shows to everyone.
    assert_select ".card-detail__card .card.card--l"
  end

  test "a set named in the query is browsed; its ends are disabled buttons; a card alone in its set has no swipe hint" do
    add_a_theme_set
    sign_in_viewer

    get in_theme("tin-soldier")
    assert_equal [ [ "button", "disabled" ], [ "a", in_theme("portal") ] ], navs
    assert_equal "S1 · #1 · 1 / 3 · swipe to browse", position

    get in_theme("blue-depths")
    assert_equal [ [ "a", in_theme("portal") ], [ "button", "disabled" ] ], navs

    valve = card_season_path(locale: :en, slug: "portal", number: 1, set_kind: "studio", set_key: "valve")
    get valve
    assert_equal [ [ "button", "disabled" ], [ "button", "disabled" ] ], navs
    assert_equal "S1 · #4 · 1 / 1", position
    assert_equal "/en/library/studio/valve", css_select(".top-bar__phone-back").sole["href"]
  end

  test "a visitor browsing a set has no way back to its album, closed to visitors" do
    add_a_theme_set

    get in_theme("portal")

    assert_equal [ [ "a", in_theme("tin-soldier") ], [ "a", in_theme("blue-depths") ] ], navs
    assert_select ".top-bar__phone-back[href^='/en/library/theme/puzzle']", false
    assert_nil css_select(".card-detail").sole["data-sub-view-back-value"]
  end

  test "a set's way back leads to the page of its album holding the card" do
    season, cards = published_cards(70)
    insert_theme(cards, key: "roguelike", season:)
    slugs = Catalog::CardSeason.where(id: cards).includes(:card).index_by(&:id).transform_values { it.card.slug }
    detail = ->(id) { card_season_path(locale: :en, slug: slugs.fetch(id), number: season.number, set_kind: "theme", set_key: "roguelike") }
    sign_in_viewer

    get detail.(cards[59])
    assert_equal "60 / 70", position[%r{\d+ / \d+}]
    assert_equal "/en/library/theme/roguelike", css_select(".top-bar__phone-back").sole["href"]

    get detail.(cards[60])
    assert_equal "61 / 70", position[%r{\d+ / \d+}]
    assert_equal "/en/library/theme/roguelike?page=2", css_select(".top-bar__phone-back").sole["href"]
  end

  test "a card opened from a player's album browses it, leads back to that album, links its sets to that player's albums and shows the face of a card that player does not hold" do
    season, cards = published_cards(70)
    insert_theme(cards, key: "roguelike", season:)
    owner = accounts_players(:player)
    hold_all(owner, [ cards[60] ])
    slugs = Catalog::CardSeason.where(id: cards).includes(:card).index_by(&:id).transform_values { it.card.slug }
    detail = ->(id) { card_season_path(locale: :en, slug: slugs.fetch(id), number: season.number, set_kind: "theme", set_key: "roguelike", brother: owner.token) }

    get detail.(cards[60])

    assert_equal "/en/brothers/#{owner.token}/library/theme/roguelike?page=2", css_select(".top-bar__phone-back").sole["href"]
    assert_equal [ [ "a", detail.(cards[59]) ], [ "a", detail.(cards[61]) ] ], navs
    assert_equal [ "/en/brothers/#{owner.token}/library/theme/roguelike" ], css_select(".card-detail__sets a").map { it["href"] }
    assert_select ".card-detail__card .card.card--l", 1

    get detail.(cards[59])

    assert_select ".card-detail__card .card.card--l", 1
    assert_select ".card-detail__card .card--not-owned", false
    assert_select ".card-detail__share-button", "Share"

    viewer = accounts_players(:moderator)
    hold_all(viewer, [ cards[59] ])
    sign_in(viewer)
    get detail.(cards[59])
    assert_select ".card-detail__card .card.card--l:not(.card--not-owned)", 1
    get detail.(cards[60])
    assert_select ".card-detail__card .card.card--l.card--not-owned", 1
  end

  test "a card opened from the album of a player whose profile may not be shown browses the viewer's own album" do
    season, cards = published_cards(5)
    insert_theme(cards, key: "roguelike", season:)
    owner = accounts_players(:player)
    owner.update!(visibility: :private)
    slug = Catalog::CardSeason.find(cards[0]).card.slug
    sign_in(Accounts::Player.create!(steam_id: "76561197960287991"))

    get card_season_path(locale: :en, slug:, number: season.number, set_kind: "theme", set_key: "roguelike", brother: owner.token)

    assert_equal "/en/library/theme/roguelike", css_select(".top-bar__phone-back").sole["href"]
    assert_select "a.card-detail__nav[href*=brother]", false
    assert_equal [ "/en/library/theme/roguelike" ], css_select(".card-detail__sets a").map { it["href"] }
  end

  test "an unknown kind, or a set that does not hold the card, is ignored: the first set, the face" do
    add_a_theme_set
    player = accounts_players(:player)
    sign_in(player)

    [ { set_kind: "nope", set_key: "puzzle" }, { set_kind: "studio", set_key: "nope" }, { set_kind: "theme", set_key: "valve" },
      { set_kind: [ "theme" ], set_key: "puzzle" }, { set_kind: "theme" } ].each do |query|
      get card_season_path(locale: :en, slug: "portal", number: 1, **query)

      assert_response :success, query.inspect
      assert_equal "S1 · #4 · 2 / 3 · swipe to browse", position, query.inspect
      assert_select ".card-detail__card .card.card--l", 1, query.inspect
    end
  end

  test "within a set, a card the viewer does not hold shows its face faded and locked, None for copies and editions, and the share block without repost or showcase" do
    add_a_theme_set
    player = accounts_players(:player)
    hold(player, catalog_card_seasons(:portal_one).id, 1)
    hold(player, catalog_card_seasons(:common_card_one).id, 0)
    sign_in(player)

    get in_theme("tin-soldier")

    assert_select ".card-detail__card .card.card--l.card--rarity-common.card--not-owned .card__title", "Tin Soldier"
    assert_select ".card-detail__card .card--not-owned > .card__lock > svg.pixel-icon[aria-hidden=true]", 1
    assert_select ".card-detail__card .card--not-owned[data-controller], .card-detail__card .card--not-owned .card__effects", false
    assert_select "#share-sheet .share-sheet__thumb .card.card--s:not(.card--not-owned)", 1
    assert_select ".card-detail h1", "Tin Soldier"
    # A card-season without a main theme shows no genre.
    assert_equal [ [ "Rarity", "Common" ], [ "Year", "2024" ], [ "Season", "Season 1" ], fixture_pioneer, [ "Sets", "Puzzle" ], [ "Copies", "None" ],
      [ "Editions", "None" ] ], facts
    assert_select ".card-detail[data-controller~=share]"
    assert_select ".card-detail__share-button", "Share"
    assert_select "#share-sheet input[value=?]", "http://www.example.com/en/cards/tin-soldier/seasons/1"
    assert_select "form[action*='/repost']", false
    assert_select ".card-detail__showcase", false

    # A card held shows its plain face, and its share block, within the set too.
    get in_theme("portal")
    assert_select ".card-detail__card .card.card--l.card--rarity-epic:not(.card--not-owned)[data-controller=tilt]"
    assert_select ".card-detail__share-button", "Share"
    assert_select "form[action='/en/cards/portal/seasons/1/repost'] button", "Repost"

    get in_theme("tin-soldier", locale: :fr)
    assert_equal [ [ "Exemplaires", "Aucun" ], [ "Éditions", "Aucune" ] ], facts.last(2)
    assert_select ".card-detail__share-button", "Partager"
  end

  test "a visitor within a set sees the card's face, its share block and its sets by name, without copies, editions, repost, showcase or set links; the card's own page is the public one" do
    add_a_theme_set

    get in_theme("portal")
    assert_select ".card-detail__card .card-float .card-rays.card-rays--epic", 1
    assert_select ".card-detail__card .card.card--l.card--rarity-epic", 1
    assert_select ".card-detail__card .card--not-owned", false
    assert_select ".card-detail__share-button", "Share"
    assert_select "#share-sheet input[value=?]", "http://www.example.com/en/cards/portal/seasons/1"
    assert_select "form[action*='/repost']", false
    assert_select ".card-detail__showcase", false
    assert_select ".card-detail__sets li", /Puzzle/
    assert_select ".card-detail__sets a", false
    assert_select "section.card-invitation", false
    assert_not_includes facts.map(&:first), "Copies"
    assert_not_includes facts.map(&:first), "Editions"
    assert_includes facts, [ "Rarity", "Epic" ]

    get card_season_path(locale: :en, slug: "portal", number: 1)
    assert_select ".public-card .card.card--xl"
    assert_select ".public-card .card--not-owned", false
    assert_select ".card-detail", false
  end

  test "an older season by its number: its rarity, its sets without links, browsing its own set, no way back to a grid" do
    publish_season_two_with_portal
    sign_in_viewer

    get card_path(locale: :en, slug: "portal")
    assert_select ".card-detail__card .card.card--rarity-legendary"
    assert_equal [ "Legendary", "Season 2" ], facts.to_h.values_at("Rarity", "Season")
    assert_equal [ [ "Puzzle", "/en/library/theme/puzzle" ] ], css_select(".card-detail__sets a").map { [ it.text, it["href"] ] }
    assert_select ".top-bar__phone-back"

    get card_season_path(locale: :en, slug: "portal", number: 1)
    assert_response :success
    assert_select ".card-detail__card .card.card--rarity-epic"
    assert_equal [ "Epic", "Season 1", "Valve" ], facts.to_h.values_at("Rarity", "Season", "Sets")
    assert_select ".card-detail__sets a", false
    assert_select ".card-detail__sets li", "Valve"
    assert_equal "S1 · #4 · 1 / 1", position
    assert_select ".top-bar__phone-back", false
    assert_select ".top-bar__start--phone-back", false
  end

  test "a card-season of an older season holding no set and no main theme shows neither sets nor genre" do
    publish_season_two_with_portal
    sign_in_viewer

    get card_season_path(locale: :en, slug: "tin-soldier", number: 1)

    assert_response :success
    assert_equal [ "Rarity", "Year", "Season", "Pioneer", "Copies", "Editions" ], facts.map(&:first)
    assert_equal "Season 1", facts.to_h["Season"]
    assert_select ".card-detail__sets", false
    assert_select ".card-detail__nav", false
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
    sign_in_viewer

    [ "/en/cards/portal?number[]=1", "/en/cards/portal?number=abc", "/en/cards/portal?number=1" ].each do |path|
      get path
      assert_response :success, path
      assert_equal "Season 2", facts.to_h["Season"], path
    end
  end

  test "with no season published no card is found" do
    catalog_seasons(:one).update_columns(status: "draft", published_at: nil)

    get card_path(locale: :en, slug: "portal")
    assert_response :not_found
  end

  test "a holder gets the share sheet: the button beside the Steam link opening it, the card's face as thumbnail, the card-season's own link, without their token, a status region" do
    player = accounts_players(:player)
    hold(player, catalog_card_seasons(:portal_one).id, 1)
    sign_in(player)

    get card_path(locale: :en, slug: "portal")

    url = "http://www.example.com/en/cards/portal/seasons/1"
    detail = css_select(".card-detail[data-controller~=share]").sole
    assert_equal [ "Link copied", "Press Ctrl+C to copy" ], [ detail["data-share-copied-value"], detail["data-share-manual-value"] ]
    assert_equal [ [ "card-detail__holder-actions", [ "button-form", "card-detail__showcase" ] ],
      [ "card-detail__card-links", [ "card-detail__share-button", "card-detail__store" ] ] ],
      css_select(".card-detail__actions > *").map { |group| [ group["class"], group.element_children.map { (it["class"].split & %w[button-form card-detail__showcase card-detail__share-button card-detail__store]).sole } ] }
    # "Repost" posts to this card-season's repost, in Turbo Stream, and stays.
    assert_select ".card-detail__holder-actions > form.button-form:first-child[method=post][action='/en/cards/portal/seasons/1/repost'] button.button--primary", "Repost"
    assert_select ".card-detail .button--primary", 1
    assert_select ".card-detail__showcase .button--secondary", "Add to showcase"
    assert_select ".card-detail__card-links a.card-detail__store.button--secondary"
    # "Share" opens the sheet and copies the link in the same click.
    button = css_select(".card-detail__actions button.button--secondary[type=button]").sole
    assert_equal [ "Share", "dialog-opener#open share#copy", "share-sheet", "dialog" ],
      [ button.text, button["data-action"], button["data-dialog-opener-dialog-value"], button["aria-haspopup"] ]
    sheet = css_select(".card-detail dialog#share-sheet.modal[aria-labelledby=share-sheet-title]").sole
    assert_equal "dialog", sheet["data-controller"]
    assert_equal "Share the card", sheet.at_css("#share-sheet-title").text
    assert_equal "Close", sheet.at_css(".modal__close")["aria-label"]
    assert_equal [ "Portal", "Epic" ], [ sheet.at_css(".share-sheet__name").text, sheet.at_css(".share-sheet__line").text ]
    # The thumbnail is the card's own face, decorative, and no image of the game.
    assert_equal 1, sheet.css(".share-sheet__thumb[aria-hidden=true] .card.card--s").size
    assert_empty sheet.css("img")
    assert_select "#share-sheet label[for=share-sheet-url]", "Link to this card"
    assert_select "#share-sheet input#share-sheet-url[type=text][readonly][data-share-target=url][value=?]", url
    assert_select "#share-sheet button[data-action='share#copy'][autofocus]", "Copy"
    assert_select "#share-sheet [role=status][data-share-target=status]", ""
    assert_select "#share-sheet .share-sheet__note", "The link's preview shows the card's title and rarity, without the game's image."
    assert_select "#share-sheet a.share-sheet__public[href=?][target=_blank][rel~=noopener]", "/en/cards/portal/seasons/1"
    assert_select "#share-sheet a.share-sheet__public .visually-hidden", "(new tab)"
    # Only the player's own menu, in the top bar, links their profile.
    assert_not_includes css_select("head, main").to_s, player.token
    # The share link is the page's own og:url.
    assert_equal url, css_select("head meta[property='og:url']").sole["content"]

    get card_path(locale: :fr, slug: "portal")
    assert_select "#share-sheet input[value=?]", "http://www.example.com/fr/cards/portal/seasons/1"
    assert_select ".card-detail__share-button", "Partager"
    assert_select ".card-detail__actions form[action='/fr/cards/portal/seasons/1/repost'] button", "Reposter"
    assert_select "#share-sheet #share-sheet-title", "Partager la carte"
    assert_select "#share-sheet .share-sheet__note", "L'aperçu du lien affiche le titre et la rareté de la carte, sans l'image du jeu."
    assert_select "#share-sheet button[data-action='share#copy']", "Copier"
    assert_equal "Appuyez sur Ctrl+C pour copier", css_select(".card-detail").sole["data-share-manual-value"]
  end

  test "the share link names the season of the card-season held, on the configured public base" do
    player = accounts_players(:player)
    hold(player, catalog_card_seasons(:portal_one).id, 1)
    publish_season_two_with_portal
    Rails.configuration.x.public_url = "https://gameble.example"
    host! "evil.example"
    sign_in(player)

    get card_season_path(locale: :en, slug: "portal", number: 1)
    assert_select "#share-sheet input[value=?]", "https://gameble.example/en/cards/portal/seasons/1"
    assert_not_includes response.body, "evil.example"

    assert_select "form[action='/en/cards/portal/seasons/1/repost']"

    get card_path(locale: :en, slug: "portal")
    assert_select "#share-sheet input[value=?]", "https://gameble.example/en/cards/portal/seasons/2"
    assert_select "form[action*='/repost']", false
  ensure
    Rails.configuration.x.public_url = @public_url
  end

  test "a player without copies gets the share block without repost; a visitor on the card's own page gets none" do
    player = accounts_players(:player)
    hold(player, catalog_card_seasons(:portal_one).id, 0)
    hold(accounts_players(:moderator), catalog_card_seasons(:portal_one).id, 1)
    sign_in(player)

    get card_path(locale: :en, slug: "portal")
    assert_select "#share-sheet input[value=?]", "http://www.example.com/en/cards/portal/seasons/1"
    assert_select ".card-detail__share-button", "Share"
    assert_select "form[action*='/repost']", false

    delete session_path(locale: :en)
    get card_path(locale: :en, slug: "portal")
    assert_select "#share-sheet", false
    assert_select "[data-controller~=share]", false
    assert_select "form[action*='/repost']", false
  end

  # The fixture season's five tiers, as an opened pack's cards, in drawn
  # order: tin-soldier, green-hills, blue-depths, portal, golden-crown.
  def pack_detail(slug, pack, slot: nil, locale: :en)
    card_season_path(locale:, slug:, number: 1, pack: pack.token, slot:)
  end

  test "opened from the player's opened pack: ◀ ▶ walk its cards in drawn order, no further; the phone's way back is the booster" do
    add_a_theme_set
    player = accounts_players(:player)
    fixture_tier_ids.each { hold(player, it, 1) }
    pack = create_pack(player, cards: fixture_tier_ids, opened_at: 1.minute.ago)
    sign_in(player)

    get pack_detail("blue-depths", pack, slot: 3)

    assert_response :success
    assert_equal [ [ "a", pack_detail("green-hills", pack, slot: 2) ], [ "a", pack_detail("portal", pack, slot: 4) ] ], navs
    assert_equal "S1 · #3 · 3 / 5 · swipe to browse", position
    assert_select ".card-detail__card .card.card--l"
    back = css_select(".top-bar__phone-back").sole
    assert_equal [ "/en/booster?pack=#{pack.token}", "history-back", "Capsule" ], [ back["href"], back["data-controller"], back.text.squish ]
    assert_equal back["href"], css_select(".card-detail").sole["data-sub-view-back-value"]

    get pack_detail("tin-soldier", pack, slot: 1)
    assert_equal [ [ "button", "disabled" ], [ "a", pack_detail("green-hills", pack, slot: 2) ] ], navs
    assert_equal "S1 · #1 · 1 / 5 · swipe to browse", position

    get pack_detail("golden-crown", pack, slot: 5, locale: :fr)
    assert_equal [ [ "a", pack_detail("portal", pack, slot: 4, locale: :fr) ], [ "button", "disabled" ] ], navs
    assert_equal "Capsule", css_select(".top-bar__phone-back").sole.text.squish
    assert_equal "/fr/booster?pack=#{pack.token}", css_select(".top-bar__phone-back").sole["href"]
  end

  test "a card drawn twice is placed by its slot, else at its first place; a card of the pack not held shows as not owned" do
    player = accounts_players(:player)
    cards = %i[portal_one common_card_one portal_one rare_card_one legendary_card_one].map { catalog_card_seasons(it).id }
    pack = create_pack(player, cards:, opened_at: 1.minute.ago)
    sign_in(player)

    get pack_detail("portal", pack, slot: 3)
    assert_equal [ [ "a", pack_detail("tin-soldier", pack, slot: 2) ], [ "a", pack_detail("blue-depths", pack, slot: 4) ] ], navs
    assert_equal "S1 · #4 · 3 / 5 · swipe to browse", position
    assert_select ".card-detail__card .card.card--l.card--rarity-epic.card--not-owned", 1

    [ nil, 2, 9, "x" ].each do |slot|
      get pack_detail("portal", pack, slot:)
      assert_equal [ [ "button", "disabled" ], [ "a", pack_detail("tin-soldier", pack, slot: 2) ] ], navs, slot.inspect
      assert_equal "S1 · #4 · 1 / 5 · swipe to browse", position, slot.inspect
    end
  end

  test "another player's pack, one not opened, an unknown token, or a pack without the card is ignored: the card's first set" do
    add_a_theme_set
    player = accounts_players(:player)
    sign_in(player)
    first_set = [ [ "a", in_theme("tin-soldier") ], [ "a", in_theme("blue-depths") ] ]
    foreign = create_pack(accounts_players(:moderator), cards: fixture_tier_ids, opened_at: 1.minute.ago)
    sealed = create_pack(player, cards: fixture_tier_ids)
    without = create_pack(player, cards: Array.new(5, catalog_card_seasons(:common_card_one).id), opened_at: 1.minute.ago)

    [ foreign.token, sealed.token, without.token, "nope", "" ].each do |token|
      get card_season_path(locale: :en, slug: "portal", number: 1, pack: token, slot: 4)

      assert_response :success, token
      assert_equal first_set, navs, token
      assert_equal "S1 · #4 · 2 / 3 · swipe to browse", position, token
      assert_equal "/en/library/theme/puzzle", css_select(".top-bar__phone-back").sole["href"], token
      assert_select ".card-detail__card .card.card--l", 1, token
    end

    get card_season_path(locale: :en, slug: "portal", number: 1, pack: { token: foreign.token })
    assert_response :success
    assert_equal first_set, navs

    # A visitor names no pack of theirs: the public card page.
    delete session_path(locale: :en)
    get card_season_path(locale: :en, slug: "portal", number: 1, pack: foreign.token)
    assert_select ".public-card"
  end

  # The slugs of the collection grid `params` asks for, every page, as the
  # library shows them.
  def grid_slugs(params)
    (1..).each_with_object([]) do |page, slugs|
      get library_cards_path(locale: :en, **params, page:)
      shown = css_select(".collection-grid a.card-link").map { it["href"][%r{/cards/([^/]+)/}, 1] }
      return slugs if shown.empty?

      slugs.concat(shown)
    end
  end

  def grid_detail(slug, number, context) = card_season_path(locale: :en, slug:, number:, grid: context)

  test "opened from the collection grid: ◀ ▶ walk the grid as shown, across its pages; the way back is the page holding the card" do
    season = publish_sets_draft
    player = accounts_players(:player)
    cards = Catalog::CardSeason.where(season_id: season.id).order(:number, :id).ids
    cards.first(3).each_with_index { |id, index| hold(player, id, 1, gained_at: index.hours.ago) }
    sign_in(player)
    slugs = grid_slugs({ state: %w[all] })
    assert_equal 150, slugs.size
    context = { q: "", state: %w[all] }

    # The last card of the first page: the first of the second follows it.
    get grid_detail(slugs[59], season.number, context)

    assert_equal [ [ "a", grid_detail(slugs[58], season.number, context) ], [ "a", grid_detail(slugs[60], season.number, context) ] ], navs
    assert_equal "60 / 150", position[%r{\d+ / \d+}]
    assert_equal "/en/library/cards?state%5B%5D=all", css_select(".top-bar__phone-back").sole["href"]
    assert_equal "Grid", css_select(".top-bar__phone-back").sole.text.squish
    assert_select ".card-detail__card .card.card--l.card--not-owned", 1
    assert_equal [ [ "Copies", "None" ], [ "Editions", "None" ] ], facts.to_h.slice("Copies", "Editions").to_a
    assert_select ".card-detail__share-button", "Share"
    assert_select "#share-sheet"
    assert_select "form[action*='/repost']", false
    assert_select ".card-detail__showcase", false

    get grid_detail(slugs[60], season.number, context)
    assert_equal "61 / 150", position[%r{\d+ / \d+}]
    assert_equal "/en/library/cards?page=2&state%5B%5D=all", css_select(".top-bar__phone-back").sole["href"]

    # The newest held card opens the grid; every slot by default.
    get grid_detail(slugs[0], season.number, { q: "" })
    assert_equal [ [ "button", "disabled" ], [ "a", grid_detail(slugs[1], season.number, { q: "" }) ] ], navs
    assert_equal "1 / 150", position[%r{\d+ / \d+}]
    assert_equal "/en/library/cards", css_select(".top-bar__phone-back").sole["href"]
    assert_select ".card-detail__card .card.card--l"
  end

  test "opened from an owner's collection grid: ◀ ▶ walk that grid, the way back is that owner's page holding the card" do
    season = publish_sets_draft
    owner = accounts_players(:moderator)
    viewer = accounts_players(:player)
    cards = Catalog::CardSeason.where(season_id: season.id).order(:number, :id).ids
    hold(owner, cards.first, 1, gained_at: 1.hour.ago)
    sign_in(viewer)
    get brother_collection_path(locale: :en, token: owner.token)
    slugs = css_select(".collection-grid a.card-link").map { it["href"][%r{/cards/([^/]+)/}, 1] }
    context = { q: "", brother: owner.token }

    get grid_detail(slugs[1], season.number, context)

    assert_equal [ [ "a", grid_detail(slugs[0], season.number, context) ], [ "a", grid_detail(slugs[2], season.number, context) ] ], navs
    assert_equal "/en/brothers/#{owner.token}/library", css_select(".top-bar__phone-back").sole["href"]
    assert_equal "Grid", css_select(".top-bar__phone-back").sole.text.squish

    get brother_collection_path(locale: :en, token: owner.token, page: 2)
    second = css_select(".collection-grid a.card-link").first["href"][%r{/cards/([^/]+)/}, 1]
    get grid_detail(second, season.number, context)
    assert_equal "/en/brothers/#{owner.token}/library?page=2", css_select(".top-bar__phone-back").sole["href"]

    get grid_detail(slugs[0], season.number, context.merge(state: %w[owned new]))
    assert_equal "1 / 1", position[%r{\d+ / \d+}]
    assert_equal "/en/brothers/#{owner.token}/library?state%5B%5D=owned", css_select(".top-bar__phone-back").sole["href"]
  end

  test "an owner's grid in a card's context is ignored when the owner is hidden or unknown" do
    season = publish_sets_draft
    owner = accounts_players(:moderator)
    owner.update!(visibility: "private")
    sign_in(accounts_players(:player))
    slug = Catalog::CardSeason.where(season_id: season.id).order(:number, :id).first.card.slug

    get card_season_path(locale: :en, slug:, number: season.number, grid: { q: "", brother: owner.token })
    assert_select ".card-detail__nav" do |navs|
      assert_not navs.any? { it["href"].to_s.include?(owner.token) }
    end
    assert_not_includes css_select(".top-bar__phone-back").map { it["href"] }.join, owner.token

    get card_season_path(locale: :en, slug:, number: season.number, grid: { q: "", brother: "A" * 24 })
    assert_response :success
    assert_not_includes response.body, "A" * 24
  end

  test "a filtered, searched grid is walked as shown, a visitor's state ignored; a grid naming a set walks the whole season's; a grid without the card is ignored" do
    season = publish_sets_draft
    context = { genre: %w[roguelike], q: "Seed 1" }
    slugs = grid_slugs(context)
    assert_operator slugs.size, :>, 2

    # A visitor owns nothing: a state the grid's context names, even one
    # no card of theirs is in, is ignored, the detail walking every card
    # the filters and search show, and its links naming no state.
    get grid_detail(slugs[1], season.number, context.merge(state: %w[owned]))
    assert_equal [ [ "a", grid_detail(slugs[0], season.number, context) ], [ "a", grid_detail(slugs[2], season.number, context) ] ], navs
    assert_equal "2 / #{slugs.size}", position[%r{\d+ / \d+}]
    assert_equal "/en/library/cards?genre%5B%5D=roguelike&q=Seed+1", css_select(".top-bar__phone-back").sole["href"]
    # A visitor browsing a grid gets the detail: the card's face and its
    # share block, without copies, editions, repost or showcase.
    assert_select ".card-detail__card .card.card--l", 1
    assert_select ".card-detail__share-button", "Share"
    assert_select "#share-sheet"
    assert_nil facts.to_h["Copies"]
    assert_nil facts.to_h["Editions"]
    assert_select "form[action*='/repost']", false
    assert_select ".card-detail__showcase", false
    assert_select "section.card-invitation", false
    assert_select ".public-card", false

    # A link built by the grid of one set, before sets opened as albums:
    # the whole season's grid with its filters, back to that grid's page.
    filtered = { q: "", rarity: %w[common rare] }
    season_slugs = grid_slugs(filtered)
    assert_operator season_slugs.size, :>, 2
    rpg = Catalog::CardSeason.where(id: set_members(season, "rpg")).includes(:card).map { it.card.slug }
    index = season_slugs[0...-1].index { it.in?(rpg) }
    rpg_slug = season_slugs[index]
    get grid_detail(rpg_slug, season.number, filtered.merge(kind: "theme", key: "rpg"))
    assert_equal "#{index + 1} / #{season_slugs.size}", position[%r{\d+ / \d+}]
    assert_equal grid_detail(season_slugs[index + 1], season.number, filtered), navs.last.last
    page = (index / CollectionGridLoading::GRID_SIZE) + 1
    assert_equal library_cards_path(locale: :en, rarity: %w[common rare], page: (page if page > 1)), css_select(".top-bar__phone-back").sole["href"]

    # A grid that does not show the card: no context, so the visitor gets
    # the public card page.
    get grid_detail(slugs[1], season.number, { q: "nothing like it" })
    assert_response :success
    assert_select ".public-card", 1
  end

  test "a grid filtered on new cards is walked against the watermark it was shown against, though showing it moved the player's" do
    season = publish_sets_draft
    player = accounts_players(:player)
    cards = Catalog::CardSeason.where(season_id: season.id).order(:number, :id).ids
    cards.first(3).each_with_index { |id, index| hold(player, id, 1, gained_at: (index + 1).hours.ago) }
    Game::PlayerState.where(player_id: player.id).update_all(collection_seen_up_to: 1.day.ago)
    sign_in(player)

    get library_cards_path(locale: :en, state: %w[new])
    links = css_select(".collection-grid a.card-link").map { it["href"] }
    assert_equal 3, links.size
    # The grid posts the latest gain it showed: none of its cards is new any more.
    Game::PlayerState.where(player_id: player.id).update_all(collection_seen_up_to: Time.current)

    get links[1]
    assert_equal links.values_at(0, 2), navs.map(&:second)
    assert_equal "2 / 3", position[%r{\d+ / \d+}]
    assert_equal "/en/library/cards?state%5B%5D=new", css_select(".top-bar__phone-back").sole["href"]

    # A watermark that is not a time is the player's current one: no new
    # card, so the card's own page, as without a grid.
    slug = links[1][%r{/cards/([^/]+)/}, 1]
    get card_season_path(locale: :en, slug:, number: season.number)
    # A seeded card may belong to no set: then it browses nothing.
    browsed = -> { [ navs, css_select(".card-detail__position").map(&:text) ] }
    own = browsed.()
    context = Rack::Utils.parse_nested_query(URI(links[1]).query)["grid"].merge("seen" => "yesterday")
    get card_season_path(locale: :en, slug:, number: season.number, grid: context)
    assert_response :success
    assert_equal own, browsed.()
  end

  test "a grid of an older season's card is ignored: the library shows the published season only" do
    add_a_theme_set
    publish_season_two_with_portal
    sign_in_viewer

    get card_season_path(locale: :en, slug: "tin-soldier", number: 1, grid: { q: "", state: %w[all] })
    assert_response :success
    assert_equal "S1 · #1 · 1 / 3 · swipe to browse", position
    assert_select ".top-bar__phone-back", false
  end

  test "a player's request costs thirteen queries, a visitor's six; a frame visit (◀ ▶) skips the top bar's" do
    player = accounts_players(:player)
    hold(player, catalog_card_seasons(:portal_one).id, 2)
    sign_in(player)

    # Player lookup, card detail, sets, neighbours, quantities, the
    # holder's showcase, the pioneer, the share image, and the top bar's four (reserve count, next pack,
    # copies per tier, rarity legend), and the tab bar's trades waiting.
    assert_request_queries(13) { get card_path(locale: :en, slug: "portal") }
    assert_response :success
    assert_equal [ "Copies", "2 copies" ], facts.to_h.assoc("Copies")
    assert_select "#share-sheet"
    assert_request_queries(8) { get card_path(locale: :en, slug: "portal"), headers: { "Turbo-Frame" => "card-detail" } }
    assert_select "turbo-frame#card-detail .card-detail h1", "Portal"

    delete session_path(locale: :en)
    # The public card page: the card detail and its sets; no neighbours; the
    # share image, the LIVE strip's entries, notable then fillers (none here), the pioneer.
    assert_request_queries(6) { get card_path(locale: :en, slug: "portal") }
    assert_response :success
    assert_select ".public-card"
  end

  test "an opened pack in place of the set costs one query more, the collection grid four more" do
    player = accounts_players(:player)
    pack = create_pack(player, cards: fixture_tier_ids, opened_at: 1.minute.ago)
    sign_in(player)

    # The eleven, the set's neighbours replaced by the pack and its two
    # neighbours' cards.
    assert_request_queries(13) { get pack_detail("blue-depths", pack, slot: 3) }
    assert_equal "S1 · #3 · 3 / 5 · swipe to browse", position

    # The set's neighbours replaced by the published season, the grid's
    # genres, the grid's cards in order and its two neighbours' cards,
    # whether a state is asked or not.
    assert_request_queries(15) { get card_season_path(locale: :en, slug: "blue-depths", number: 1, grid: { q: "" }) }
    assert_select ".card-detail__nav", 2
    assert_request_queries(15) { get card_season_path(locale: :en, slug: "blue-depths", number: 1, grid: { q: "", state: %w[all] }) }
  end

  # The row of a card whose fixture pioneer is the banned player.
  def fixture_pioneer(locale: :en)
    date = 2.weeks.ago.to_date
    day = I18n.l(date, format: (date.day == 1 ? :long_day_first : :long_day), locale:)
    locale == :en ? [ "Pioneer", "An anonymous player on #{day}" ] : [ "Pionnier", "Un joueur anonyme le #{day}" ]
  end

  def pioneer_row = css_select(".card-detail__pioneer").first

  # Makes `player` the first to have pulled portal in the fixture season, on `day`.
  def pioneered_by(player, day: Time.utc(2026, 3, 14, 12))
    Game::FirstDiscovery.where(card_season_id: catalog_card_seasons(:portal_one).id).update_all(player_id: player.id, discovered_at: day)
  end

  test "the pioneer is named with a link to their profile and the discovery date" do
    pioneer = accounts_players(:moderator)
    pioneer.update!(persona_name: "Léa")
    pioneered_by(pioneer)
    sign_in(accounts_players(:player))

    get card_path(locale: :en, slug: "portal")

    assert_equal [ "Pioneer", "Léa on March 14, 2026" ], facts.assoc("Pioneer")
    assert_select ".card-detail__pioneer a[href=?]", brother_path(locale: :en, token: pioneer.token), "Léa"
    assert_equal "Season 1", facts.to_h["Season"]
    assert_equal %w[Season Pioneer], facts.map(&:first).each_cons(2).find { |a, b| b == "Pioneer" }
  end

  test "a banned pioneer reads as an anonymous player with the date and no link, to staff too" do
    sign_in(accounts_players(:administrator))

    get card_path(locale: :en, slug: "portal")

    assert_equal [ "Pioneer", "An anonymous player on #{I18n.l(2.weeks.ago.to_date, format: :long_day, locale: :en)}" ], facts.assoc("Pioneer")
    assert_select ".card-detail__pioneer a", false
  end

  test "a deleted pioneer, or a private profile, reads as an anonymous player" do
    pioneer = accounts_players(:moderator)
    pioneered_by(pioneer)
    pioneer.update!(visibility: :private)
    sign_in(accounts_players(:player))

    get card_path(locale: :en, slug: "portal")

    assert_select ".card-detail__pioneer-anon", "An anonymous player"
    assert_select ".card-detail__pioneer a", false
    pioneer.update_columns(deleted_at: Time.current, steam_id: nil, visibility: Accounts::Player.visibilities.fetch(:public))
    get card_path(locale: :en, slug: "portal")
    assert_select ".card-detail__pioneer-anon", "An anonymous player"
  end

  test "a visitor browsing a context reads the name of a public profile, and a friends-only profile as anonymous" do
    pioneer = accounts_players(:moderator)
    pioneer.update!(persona_name: "Léa")
    pioneered_by(pioneer)
    owner = accounts_players(:player)

    get card_season_path(locale: :en, slug: "portal", number: 1, brother: owner.token)
    assert_select ".card-detail__pioneer a", "Léa"

    pioneer.update!(visibility: :friends_only)
    get card_season_path(locale: :en, slug: "portal", number: 1, brother: owner.token)
    assert_select ".card-detail__pioneer-anon"
  end

  test "each edition of a card names its own pioneer, whichever season is published" do
    first = accounts_players(:moderator)
    first.update!(persona_name: "Léa")
    pioneered_by(first, day: Time.utc(2026, 3, 14, 12))
    season_two = publish_season_two_with_portal
    portal_two = Catalog::CardSeason.find_by!(card_id: catalog_cards(:portal).id, season_id: season_two.id)
    second = accounts_players(:player)
    second.update!(persona_name: "Max")
    Game::FirstDiscovery.create!(card_season_id: portal_two.id, player_id: second.id, discovered_at: Time.utc(2026, 5, 2, 12))
    sign_in(accounts_players(:administrator))

    get card_season_path(locale: :en, slug: "portal", number: 1)
    assert_equal "Léa on March 14, 2026", facts.assoc("Pioneer").last
    assert_select ".card-detail__pioneer a[href=?]", brother_path(locale: :en, token: first.token)

    get card_season_path(locale: :en, slug: "portal", number: 2)
    assert_equal "Max on May 2, 2026", facts.assoc("Pioneer").last

    get card_path(locale: :en, slug: "portal")
    assert_equal "Max on May 2, 2026", facts.assoc("Pioneer").last
  end

  test "an edition with no recorded discovery shows no pioneer while another edition of the card has one" do
    season_two = publish_season_two_with_portal
    portal_two = Catalog::CardSeason.find_by!(card_id: catalog_cards(:portal).id, season_id: season_two.id)
    Game::FirstDiscovery.create!(card_season_id: portal_two.id, player_id: accounts_players(:moderator).id, discovered_at: Time.utc(2026, 5, 2))
    Game::FirstDiscovery.where(card_season_id: catalog_card_seasons(:portal_one).id).delete_all
    sign_in(accounts_players(:player))

    get card_season_path(locale: :en, slug: "portal", number: 1)
    assert_nil facts.assoc("Pioneer")

    get card_season_path(locale: :en, slug: "portal", number: 2)
    assert_not_nil facts.assoc("Pioneer")
  end

  test "a card without a recorded discovery shows no pioneer row" do
    Game::FirstDiscovery.where(card_season_id: catalog_card_seasons(:portal_one).id).delete_all
    sign_in(accounts_players(:player))
    get card_path(locale: :en, slug: "portal")
    assert_nil facts.assoc("Pioneer")
  end

  test "the public card page shows the pioneer between the rarity line and the description, named or anonymous, with no id" do
    pioneer = accounts_players(:moderator)
    pioneer.update!(persona_name: "Léa")
    pioneered_by(pioneer)

    get card_path(locale: :en, slug: "portal")

    assert_select ".public-card__line + .public-card__pioneer + .public-card__description"
    assert_select ".public-card__pioneer a[href=?]", brother_path(locale: :en, token: pioneer.token), "Léa"
    assert_match(/March 14, 2026/, css_select(".public-card__pioneer").text)
    assert_no_match(/\b#{pioneer.id}\b/, response.body)

    pioneer.update!(visibility: :private)
    get card_path(locale: :en, slug: "portal")
    assert_select ".public-card__pioneer a", false
    assert_match(/An anonymous player/, css_select(".public-card__pioneer").text)

    Game::FirstDiscovery.delete_all
    get card_path(locale: :en, slug: "portal")
    assert_select ".public-card__pioneer", false
  end

  test "the first of a month reads « le 1er mars 2026 » in French" do
    pioneered_by(accounts_players(:moderator), day: Time.utc(2026, 3, 1, 12))
    sign_in(accounts_players(:player))

    get card_path(locale: :fr, slug: "portal")
    assert_match(/le 1er mars 2026/, pioneer_row.text)

    pioneered_by(accounts_players(:moderator), day: Time.utc(2026, 3, 2, 12))
    get card_path(locale: :fr, slug: "portal")
    assert_match(/le 2 mars 2026/, pioneer_row.text)
  end

  test "no database id reaches the page" do
    add_a_theme_set
    player = accounts_players(:player)
    hold(player, catalog_card_seasons(:portal_one).id, 2)
    sign_in(player)
    ids = [ catalog_cards(:portal).id, catalog_card_seasons(:portal_one).id, catalog_seasons(:one).id, catalog_sets(:valve_one).id,
      catalog_card_texts(:portal_en).id, catalog_card_seasons(:common_card_one).id, catalog_card_seasons(:rare_card_one).id, player.id,
      accounts_players(:banned).id ]

    get in_theme("portal")

    assert_select ".card-detail [data-id]", false
    html = css_select(".card-detail").sole.to_html
    ids.each do |id|
      next if id < 10 # a season number, a year digit or a count would match

      assert_no_match(/\b#{id}\b/, html, "id #{id} on the page")
    end
    assert_no_match(/\b#{catalog_card_seasons(:portal_one).id}\b/, response.body)
  end

  def portal_edition(number, rarity:)
    season = Catalog::Season.create!(status: :draft, number:)
    season.update!(status: :published, published_at: Time.current)
    Catalog::CardSeason.insert_all!([ { card_id: catalog_cards(:portal).id, season_id: season.id, prestige_score: 0.5, rating: 90, rarity:, number: 1 } ],
      returning: :id).rows.flatten.sole
  end

  def editions_row = facts.to_h["Editions"] || facts.to_h["Éditions"]

  test "a game held in two editions: its copies over both, and an editions row per rarity, the best first, on either edition's page" do
    player = accounts_players(:player)
    hold(player, catalog_card_seasons(:portal_one).id, 1)
    publish_season_two_with_portal
    hold(player, Catalog::CardSeason.find_by!(card_id: catalog_cards(:portal).id, season_id: Catalog::Season.find_by!(number: 2).id).id, 1)
    sign_in(player)

    get card_path(locale: :en, slug: "portal")
    assert_equal [ [ "Copies", "2 copies" ], [ "Editions", "Legendary: S2 | Epic: S1" ] ], facts.to_h.slice("Copies", "Editions").to_a
    assert_equal "Copies", facts[facts.index { it.first == "Editions" } - 1].first
    assert_select ".card-detail__editions-fold", false
    assert_select "[style]", 0

    get card_season_path(locale: :fr, slug: "portal", number: 1)
    assert_equal [ [ "Exemplaires", "2 exemplaires" ], [ "Éditions", "Légendaire : S2 | Épique : S1" ] ], facts.to_h.slice("Exemplaires", "Éditions").to_a
  end

  test "the editions of one rarity share a line, seasons ascending; past three lines they fold under how many more" do
    player = accounts_players(:player)
    hold(player, catalog_card_seasons(:portal_one).id, 1)
    hold(player, portal_edition(4, rarity: "rare"), 1)
    hold(player, portal_edition(2, rarity: "rare"), 2)
    hold(player, portal_edition(3, rarity: "legendary"), 1)
    hold(player, portal_edition(5, rarity: "common"), 1)
    hold(player, portal_edition(6, rarity: "uncommon"), 0)
    sign_in(player)

    get card_season_path(locale: :en, slug: "portal", number: 1)
    assert_equal [ "Copies", "6 copies" ], facts.to_h.assoc("Copies")
    assert_equal [ "Legendary: S3", "Epic: S1", "Rare: S2, S4" ], css_select(".card-detail__fact dd > ul.card-detail__editions li").map(&:text)
    assert_select "details.card-detail__editions-fold:not([open]) > summary.card-detail__editions-more", "1 more rarity"
    assert_equal [ "Common: S5" ], css_select("details.card-detail__editions-fold li").map(&:text)

    get card_season_path(locale: :fr, slug: "portal", number: 1)
    assert_select "details.card-detail__editions-fold > summary", "1 autre rareté"
  end

  test "editions read None without a copy; no editions row for a visitor; a holder of another edition sees the card's face" do
    hold(accounts_players(:moderator), catalog_card_seasons(:rare_card_one).id, 0)
    sign_in_viewer
    get card_path(locale: :en, slug: "portal")
    assert_equal [ [ "Copies", "None" ], [ "Editions", "None" ] ], facts.last(2)

    get card_path(locale: :fr, slug: "portal")
    assert_equal [ [ "Exemplaires", "Aucun" ], [ "Éditions", "Aucune" ] ], facts.last(2)

    delete session_path(locale: :en)
    get card_season_path(locale: :en, slug: "portal", number: 1, grid: { q: "" })
    assert_select ".card-detail"
    assert_nil facts.to_h["Copies"]
    assert_nil editions_row

    player = accounts_players(:player)
    hold(player, catalog_card_seasons(:portal_one).id, 1)
    publish_season_two_with_portal
    sign_in(player)
    get card_path(locale: :en, slug: "portal", set_kind: "theme", set_key: "puzzle")
    assert_equal "S2 · #1 · 1 / 1", position
    assert_select ".card-detail__card .card.card--rarity-legendary:not(.card--not-owned)"
  end

  test "the grid walks a tile of an earlier edition, as the grid shows it" do
    player = accounts_players(:player)
    hold(player, catalog_card_seasons(:common_card_one).id, 1, gained_at: 2.minutes.ago)
    hold(player, catalog_card_seasons(:rare_card_one).id, 1, gained_at: 1.minute.ago)
    publish_season_two_with_portal
    sign_in(player)

    get card_season_path(locale: :en, slug: "tin-soldier", number: 1, grid: { q: "" })
    assert_response :success
    assert_equal "S1 · #1 · 2 / 3 · swipe to browse", position
    assert_equal [ [ "a", "/en/cards/blue-depths/seasons/1?grid%5Bq%5D=" ], [ "a", "/en/cards/portal/seasons/2?grid%5Bq%5D=" ] ], navs
  end

  test "epic detail floats with purple rays; common detail stays still with no rays" do
    viewer = accounts_players(:moderator)
    hold(viewer, catalog_card_seasons(:portal_one).id, 1)
    hold(viewer, catalog_card_seasons(:common_card_one).id, 1)
    sign_in(viewer)

    get card_path(locale: :en, slug: "portal")
    assert_response :success
    assert_select ".card-detail__card .card-float .card-rays.card-rays--epic", 1
    assert_select ".card-detail__card .card-float .card.card--l", 1

    get card_path(locale: :en, slug: "tin-soldier")
    assert_response :success
    assert_select ".card-detail__card .card-float", 0
    assert_select ".card-detail__card .card-rays", 0
    assert_select ".card-detail__shadow", 1
  end

  test "an epic not held, within a set, is faded and locked, without float or rays" do
    add_a_theme_set
    player = accounts_players(:player)
    hold(player, catalog_card_seasons(:common_card_one).id, 1)
    sign_in(player)

    get in_theme("portal")

    assert_response :success
    assert_select ".card-detail__card .card-float", 0
    assert_select ".card-detail__card .card-rays", 0
    assert_select ".card-detail__card .card.card--l.card--rarity-epic.card--not-owned > .card__lock", 1
    assert_select ".card-detail__shadow", 1
  end

  test "epic public page floats with rays; common public page stays still" do
    get card_path(locale: :en, slug: "portal")
    assert_response :success
    assert_select ".public-card__stage .card-float .card-rays.card-rays--epic", 1
    assert_select ".public-card__stage .card-float .card.card--xl", 1
    assert_select ".public-card__shadow", 1

    get card_path(locale: :en, slug: "tin-soldier")
    assert_response :success
    assert_select ".public-card__stage .card-float", 0
    assert_select ".public-card__stage .card-rays", 0
    assert_select ".public-card__shadow", 1
  end

  # The showcase buttons as [ label, the verb their form sends or "disabled" ].
  def showcase_buttons
    css_select(".card-detail__showcase button").map do |button|
      form = button.ancestors("form").first
      verb = form && (form.at_css("input[name=_method]")&.[]("value") || form["method"])
      [ button.text.squish, button["disabled"] ? "disabled" : verb ]
    end
  end

  test "a holder puts the card in their showcase, takes it out once there, and sees the add disabled with the showcase-full line at five" do
    player = accounts_players(:player)
    fixture_tier_ids.each { hold(player, it, 1) }
    sign_in(player)

    get card_season_path(locale: :fr, slug: "portal", number: 1)
    assert_equal [ [ "Mettre en vitrine", "post" ] ], showcase_buttons
    assert_select ".card-detail__actions .card-detail__showcase form[action='/fr/cards/portal/seasons/1/showcase']"
    assert_select ".card-detail__showcase-full", false

    Game::AddToShowcase.new.call(player:, card_season_id: catalog_card_seasons(:portal_one).id).value!
    get card_season_path(locale: :fr, slug: "portal", number: 1)
    assert_equal [ [ "Retirer de la vitrine", "delete" ] ], showcase_buttons

    fixture_tier_ids.excluding(catalog_card_seasons(:portal_one).id).each { Game::AddToShowcase.new.call(player:, card_season_id: it).value! }
    season = Catalog::Season.create!(status: :draft, number: Catalog::Season.next_number)
    extra = Catalog::CardSeason.create!(card: catalog_cards(:portal), season:, prestige_score: 0.5, rating: 80.0)
    Game::RemoveFromShowcase.new.call(player:, card_season_id: catalog_card_seasons(:portal_one).id).value!
    hold(player, extra.id, 1)
    Game::AddToShowcase.new.call(player:, card_season_id: extra.id).value!

    get card_season_path(locale: :en, slug: "portal", number: 1)
    assert_equal [ [ "Add to showcase", "disabled" ] ], showcase_buttons
    assert_select ".card-detail__showcase form", false
    assert_select ".card-detail__holder-actions > .card-detail__showcase + .card-detail__showcase-full:last-child", "Showcase full: remove a card to add another."
    assert_select ".card-detail__holder-actions > form.button-form:first-child button.button--primary", "Repost"
  end

  test "no showcase button for a card not held, nor for a visitor" do
    player = accounts_players(:player)
    hold(player, catalog_card_seasons(:portal_one).id, 0)
    sign_in(player)

    get card_season_path(locale: :en, slug: "portal", number: 1)
    assert_select ".card-detail__showcase", false

    delete session_path(locale: :en)
    get card_season_path(locale: :en, slug: "portal", number: 1, set_kind: "studio", set_key: "valve")
    assert_select ".card-detail"
    assert_select ".card-detail__showcase", false
  end

  test "a card opened from a player's showcase browses its first set as that player's album does, leads back to their profile and shows as not owned to a viewer without it" do
    owner = accounts_players(:player)
    sign_in_viewer

    get card_season_path(locale: :fr, slug: "portal", number: 1, brother: owner.token)

    back = css_select(".top-bar__phone-back").sole
    assert_equal [ "/fr/brothers/#{owner.token}", "Profil" ], [ back["href"], back.text.squish ]
    assert_select ".card-detail__card .card.card--l.card--not-owned", 1
    assert_equal "S1 · #4 · 1 / 1", position

    delete session_path(locale: :en)
    get card_season_path(locale: :en, slug: "portal", number: 1, brother: owner.token)
    assert_select ".public-card", false
    assert_equal "/en/brothers/#{owner.token}", css_select(".top-bar__phone-back").sole["href"]

    owner.update!(visibility: :private)
    get card_season_path(locale: :en, slug: "portal", number: 1, brother: owner.token)
    assert_select ".public-card"
  end
end
