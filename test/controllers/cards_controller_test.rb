require "test_helper"
require_relative "../support/catalog_seeds"
require_relative "../support/library_requests"
require_relative "../support/game_packs"

# A card's detail page (CAP-7, story 4.3; "FICHE DE LA CARTE", epic 10 R2,
# R6): every fact in the viewer's language, the viewer's copies, the sets
# leading to their grids, the Steam link; open to a visitor; a holder's
# share link, the page's own address; what it browses (an opened
# pack, the collection grid as shown, a set), its ◀ ▶ and position line,
# the faded card back of a card not held within one, the phone's way back
# to it; the cards that are not found; the
# queries of a request; no database id on the page. Most tests read the
# detail as a signed-in viewer: a visitor on the card's own page gets the
# public card page instead (story 10.3), which, with the preview tags, is
# covered in card_preview_tags_test.rb.
class CardsControllerTest < ActionDispatch::IntegrationTest
  include CatalogSeeds
  include LibraryRequests
  include GamePacks

  setup do
    # A PUBLIC_URL exported in the shell would replace the request's base.
    @public_url = Rails.configuration.x.public_url
    Rails.configuration.x.public_url = nil
    OmniAuth.config.test_mode = true
  end

  teardown do
    OmniAuth.config.mock_auth.delete(:steam)
    OmniAuth.config.test_mode = false
    Rails.configuration.x.public_url = @public_url
  end

  # A tome of the fixture season holding, in slot order, tin-soldier,
  # portal and blue-depths (positions 2, 1, 3 by id), beside portal's
  # publisher set.
  def add_a_tome
    set_id = Catalog::Set.insert_all!([ { season_id: catalog_seasons(:one).id, kind: "tome", key: "action-1",
      params: { "genre" => "action", "volume" => 1, "volumes" => 1 } } ], returning: :id).rows.flatten.first
    Catalog::SetMembership.insert_all!([ [ :portal_one, 2 ], [ :common_card_one, 1 ], [ :rare_card_one, 3 ] ].map do |card_season, position|
      { set_id:, card_season_id: catalog_card_seasons(card_season).id, position: }
    end)
  end

  # A published season numbered 2 holding portal (legendary).
  def publish_season_two_with_portal
    season = seed_published_sets([ [ "tome", "action-1", { "genre" => "action", "volume" => 1, "volumes" => 1 } ] ])
    card_season_id = Catalog::CardSeason.insert_all!([ { card_id: catalog_cards(:portal).id, season_id: season.id, prestige_score: 0.99,
      rating: 99, rarity: 5 } ], returning: :id).rows.flatten.first
    Catalog::SetMembership.insert_all!([ { set_id: Catalog::Set.find_by!(season_id: season.id).id, card_season_id:, position: 1 } ])
    season
  end

  def in_tome(slug, locale: :en, number: 1) = card_season_path(locale:, slug:, number:, set_kind: "tome", set_key: "action-1")

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

  test "a card of the published season: the bracketed panel, its face, every fact, the sets leading to their grids, no ownership notice, the Steam link" do
    add_a_tome
    sign_in_viewer

    get card_path(locale: :en, slug: "portal")

    assert_response :success
    assert_select "title", "Portal — Epic"
    assert_select "main > turbo-frame#card-detail[target=_top] > article.card-detail.panel.panel--brackets[aria-labelledby=card-detail-heading]"
    assert_select ".card-detail__kicker", "Card file"
    assert_select ".card-detail__number", "S1 · #4"
    assert_select ".card-detail h1#card-detail-heading", "Portal"
    assert_select ".card-detail__card .card.card--l.card--rarity-epic .card__title", "Portal"
    assert_select ".card-detail__back", false
    assert_select "[style]", 0
    assert_select ".card-detail__description", "A puzzle game of portals."
    assert_equal [ [ "Publisher", "Valve" ], [ "Rarity", "Epic" ], [ "Genre", "Action" ], [ "Year", "2007" ], [ "Season", "Season 1" ],
      [ "Sets", "Action · Tome 1 | Valve" ], [ "Copies", "None" ] ], facts
    assert_select ".card-detail__rarity.card-detail__rarity--epic svg.card-detail__rarity-icon[aria-hidden=true]"
    assert_equal [ [ "Action · Tome 1", "/en/library/tome/action-1" ], [ "Valve", "/en/library/publisher/valve" ] ],
      css_select(".card-detail__sets a").map { [ it.text, it["href"] ] }
    assert_select ".card-detail__notice", false
    assert_no_match(/not affiliated|belong to their/i, response.body)
    assert_equal [ "See on Steam (new tab)", "https://store.example.test/400", "noopener noreferrer external", "_blank" ],
      store_link.then { [ it.text.squish, it["href"], it["rel"], it["target"] ] }
    assert_includes store_link["class"], "button--primary"
    assert_select ".card-detail .button--primary", 1
    # The description is never on the face.
    assert_no_match(/portals/, css_select(".card-detail__card").sole.text)
    assert_no_match(/collection of/i, response.body)
    assert_select ".top-bar__start > a.button--secondary[href='/en']", "Bridge"
  end

  test "in French every fact, the title, description and Steam page are French" do
    add_a_tome
    sign_in_viewer
    catalog_cards(:common_card).update_columns(store_url: "https://store.steampowered.com/app/401/Tin_Soldier/?snr=1_7&l=english")

    get card_path(locale: :fr, slug: "tin-soldier")

    assert_select ".card-detail h1", "Soldat de plomb"
    assert_select "title", "Soldat de plomb — Commune"
    assert_select ".card-detail__kicker", "Fiche de la carte"
    assert_equal [ [ "Rareté", "Commune" ], [ "Genre", "Action" ], [ "Année", "2024" ], [ "Saison", "Saison 1" ], [ "Sets", "Action · Tome 1" ], [ "Exemplaires", "Aucun" ] ], facts
    assert_equal [ "Voir sur Steam (nouvel onglet)", "https://store.steampowered.com/app/401/Tin_Soldier/?snr=1_7&l=french" ],
      store_link.then { [ it.text.squish, it["href"] ] }
    assert_equal [ "Carte précédente", "Carte suivante" ], css_select(".card-detail__nav").map { it["aria-label"] }
    assert_equal "S1 · #1 · 1 / 3 · glissez pour parcourir", position

    get card_path(locale: :fr, slug: "portal")
    assert_select ".card-detail__description", "Un jeu de casse-tête à portails."
    assert_equal "https://store.example.test/400?l=french", store_link["href"]
    assert_equal [ "Éditeur", "Rareté", "Genre", "Année", "Saison", "Sets", "Exemplaires" ], facts.map(&:first)
  end

  test "a card without publisher, description, genre or set leaves those rows out, without ◀ ▶ or position line" do
    sign_in_viewer
    get card_path(locale: :en, slug: "tin-soldier")

    assert_response :success
    assert_equal [ "Rarity", "Year", "Season", "Copies" ], facts.map(&:first)
    assert_select ".card-detail__description", false
    assert_select ".card-detail__sets", false
    assert_select ".card-detail__nav", false
    assert_select ".card-detail__position", false
    assert_select ".top-bar__phone-back", false
  end

  test "a player sees their copies: two, one, or None; in French too" do
    player = accounts_players(:player)
    hold(player, catalog_card_seasons(:portal_one).id, 2)
    hold(player, catalog_card_seasons(:legendary_card_one).id, 1)
    hold(player, catalog_card_seasons(:common_card_one).id, 0)
    sign_in(player)

    get card_path(locale: :en, slug: "portal")
    assert_equal [ "Copies", "2 copies" ], facts.last

    get card_path(locale: :en, slug: "golden-crown")
    assert_equal [ "Copies", "1 copy" ], facts.last

    get card_path(locale: :fr, slug: "golden-crown")
    assert_equal [ "Exemplaires", "1 exemplaire" ], facts.last

    get card_path(locale: :en, slug: "tin-soldier")
    assert_equal [ "Copies", "None" ], facts.last

    get card_path(locale: :fr, slug: "green-hills")
    assert_equal [ "Exemplaires", "Aucun" ], facts.last
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
    assert_select ".top-bar__brand"
    assert_select "nav.tab-bar", false
    assert_select "body.is-public-page"
    assert_select ".top-bar__end form.steam-sign-in"
  end

  test "the card's own page browses its first set, tomes first: ◀ ▶ carry that set, the position line, the phone's way back to its grid" do
    add_a_tome
    sign_in_viewer

    get card_path(locale: :en, slug: "portal")

    assert_equal [ [ "a", in_tome("tin-soldier") ], [ "a", in_tome("blue-depths") ] ], navs
    assert_equal [ "Previous card", "Next card" ], css_select(".card-detail__nav").map { it["aria-label"] }
    css_select("a.card-detail__nav").each do |link|
      assert_equal [ "card-detail", "replace", "false" ], [ link["data-turbo-frame"], link["data-turbo-action"], link["data-turbo-prefetch"] ]
    end
    assert_equal "S1 · #4 · 2 / 3 · swipe to browse", position
    back = css_select(".top-bar__start.top-bar__start--phone-back > a.top-bar__phone-back").sole
    assert_equal [ "/en/library/tome/action-1", "history-back", "Grid" ], [ back["href"], back["data-controller"], back.text.squish ]
    assert_equal "/en/library/tome/action-1", css_select(".card-detail").sole["data-sub-view-back-value"]
    # The bridge stays, for the desktop.
    assert_select ".top-bar__start > a.button--secondary[href='/en']", "Bridge"
    # Without a set in the query, the face shows to everyone.
    assert_select ".card-detail__card .card.card--l"
  end

  test "a set named in the query is browsed; its ends are disabled buttons; a card alone in its set has no swipe hint" do
    add_a_tome

    get in_tome("tin-soldier")
    assert_equal [ [ "button", "disabled" ], [ "a", in_tome("portal") ] ], navs
    assert_equal "S1 · #1 · 1 / 3 · swipe to browse", position

    get in_tome("blue-depths")
    assert_equal [ [ "a", in_tome("portal") ], [ "button", "disabled" ] ], navs

    valve = card_season_path(locale: :en, slug: "portal", number: 1, set_kind: "publisher", set_key: "valve")
    get valve
    assert_equal [ [ "button", "disabled" ], [ "button", "disabled" ] ], navs
    assert_equal "S1 · #4 · 1 / 1", position
    assert_equal "/en/library/publisher/valve", css_select(".top-bar__phone-back").sole["href"]
  end

  test "an unnumbered card's position line keeps its season, and its header shows no number" do
    add_a_tome
    Catalog::CardSeason.where(id: catalog_card_seasons(:portal_one).id).update_all(number: nil)

    get in_tome("portal")

    assert_equal "S1 · 2 / 3 · swipe to browse", position
    assert_select ".card-detail__number", false
  end

  test "an unknown kind, or a set that does not hold the card, is ignored: the first set, the face" do
    add_a_tome
    player = accounts_players(:player)
    sign_in(player)

    [ { set_kind: "nope", set_key: "action-1" }, { set_kind: "publisher", set_key: "nope" }, { set_kind: "tome", set_key: "valve" },
      { set_kind: [ "tome" ], set_key: "action-1" }, { set_kind: "tome" } ].each do |query|
      get card_season_path(locale: :en, slug: "portal", number: 1, **query)

      assert_response :success, query.inspect
      assert_equal "S1 · #4 · 2 / 3 · swipe to browse", position, query.inspect
      assert_select ".card-detail__card .card.card--l", 1, query.inspect
      assert_select ".card-detail__back", false
    end
  end

  test "within a set, a card the viewer does not hold is their card back, faded, with its title, year and rarity" do
    add_a_tome
    player = accounts_players(:player)
    hold(player, catalog_card_seasons(:portal_one).id, 1)
    hold(player, catalog_card_seasons(:common_card_one).id, 0)
    sign_in(player)

    get in_tome("tin-soldier")

    assert_select ".card-detail__card .card", false
    back = css_select(".card-detail__back img.card-detail__back-image").sole
    assert_match %r{/back-standard-l[^/]*\.png\z}, back["src"]
    assert_equal [ "", "208", "312" ], [ back["alt"], back["width"], back["height"] ]
    assert_select ".card-detail__back-title[aria-hidden=true]", "Tin Soldier"
    assert_select ".card-detail__back-year[aria-hidden=true]", "2024"
    assert_select ".card-detail__not-owned", "Not owned"
    assert_select ".card-detail h1", "Tin Soldier"
    assert_equal [ [ "Rarity", "Common" ], [ "Genre", "Action" ], [ "Year", "2024" ], [ "Season", "Season 1" ], [ "Sets", "Action · Tome 1" ],
      [ "Copies", "None" ] ], facts
    assert_select "[data-controller~=share]", false
    assert_select ".card-detail__share-button", false
    assert_select "form[action*='/repost']", false

    # A card held shows its face, and its share block, within the set too.
    get in_tome("portal")
    assert_select ".card-detail__card .card.card--l.card--rarity-epic"
    assert_select ".card-detail__back", false
    assert_select ".card-detail__share-button", "Share"
    assert_select "form[action='/en/cards/portal/seasons/1/repost'] button", "Repost"

    get in_tome("tin-soldier", locale: :fr)
    assert_select ".card-detail__not-owned", "Non possédée"
  end

  test "a visitor within a set sees every card as the Standard back, without a copies row; the card's own page shows the face" do
    add_a_tome

    get in_tome("portal")
    assert_select ".card-detail__back img[src*='back-standard']"
    assert_select ".card-detail__card .card", false
    assert_not_includes facts.map(&:first), "Copies"
    assert_includes facts, [ "Rarity", "Epic" ]

    get card_season_path(locale: :en, slug: "portal", number: 1)
    assert_select ".public-card .card.card--xl"
    assert_select ".card-detail__back", false
  end

  test "the card back helper knows only the exported backs" do
    helper = ApplicationController.new.view_context
    assert_raises(ArgumentError) { helper.card_back_image("aurore") }
    assert_match(/back-standard/, helper.card_back_image("standard"))
  end

  test "an older season by its number: its rarity, its sets without links, browsing its own set, no way back to a grid" do
    publish_season_two_with_portal
    sign_in_viewer

    get card_path(locale: :en, slug: "portal")
    assert_select ".card-detail__card .card.card--rarity-legendary"
    assert_equal [ "Legendary", "Season 2" ], facts.to_h.values_at("Rarity", "Season")
    assert_equal [ [ "Action · Tome 1", "/en/library/tome/action-1" ] ], css_select(".card-detail__sets a").map { [ it.text, it["href"] ] }
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
    assert_equal [ "card-detail__store", "card-detail__share-button", "button-form" ],
      css_select(".card-detail__actions > *").map { (it["class"].split & %w[card-detail__store card-detail__share-button button-form]).sole }
    # "Repost" posts to this card-season's repost, in Turbo Stream, and stays.
    assert_select ".card-detail__actions form.button-form[method=post][action='/en/cards/portal/seasons/1/repost'] button.button--secondary", "Repost"
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
    assert_select ".card-detail__share", false
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

    # Season 2's portal is not held.
    get card_path(locale: :en, slug: "portal")
    assert_select ".card-detail__share", false
    assert_select "form[action*='/repost']", false
  ensure
    Rails.configuration.x.public_url = @public_url
  end

  test "no share block for a player without copies, nor for a visitor" do
    player = accounts_players(:player)
    hold(player, catalog_card_seasons(:portal_one).id, 0)
    hold(accounts_players(:moderator), catalog_card_seasons(:portal_one).id, 1)
    sign_in(player)

    get card_path(locale: :en, slug: "portal")
    assert_select "#share-sheet", false
    assert_select ".card-detail__share-button", false
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
    add_a_tome
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
    assert_equal [ "/en/booster?pack=#{pack.token}", "history-back", "Booster" ], [ back["href"], back["data-controller"], back.text.squish ]
    assert_equal back["href"], css_select(".card-detail").sole["data-sub-view-back-value"]

    get pack_detail("tin-soldier", pack, slot: 1)
    assert_equal [ [ "button", "disabled" ], [ "a", pack_detail("green-hills", pack, slot: 2) ] ], navs
    assert_equal "S1 · #1 · 1 / 5 · swipe to browse", position

    get pack_detail("golden-crown", pack, slot: 5, locale: :fr)
    assert_equal [ [ "a", pack_detail("portal", pack, slot: 4, locale: :fr) ], [ "button", "disabled" ] ], navs
    assert_equal "Booster", css_select(".top-bar__phone-back").sole.text.squish
    assert_equal "/fr/booster?pack=#{pack.token}", css_select(".top-bar__phone-back").sole["href"]
  end

  test "a card drawn twice is placed by its slot, else at its first place; a card of the pack not held is the faded back" do
    player = accounts_players(:player)
    cards = %i[portal_one common_card_one portal_one rare_card_one legendary_card_one].map { catalog_card_seasons(it).id }
    pack = create_pack(player, cards:, opened_at: 1.minute.ago)
    sign_in(player)

    get pack_detail("portal", pack, slot: 3)
    assert_equal [ [ "a", pack_detail("tin-soldier", pack, slot: 2) ], [ "a", pack_detail("blue-depths", pack, slot: 4) ] ], navs
    assert_equal "S1 · #4 · 3 / 5 · swipe to browse", position
    assert_select ".card-detail__back"

    [ nil, 2, 9, "x" ].each do |slot|
      get pack_detail("portal", pack, slot:)
      assert_equal [ [ "button", "disabled" ], [ "a", pack_detail("tin-soldier", pack, slot: 2) ] ], navs, slot.inspect
      assert_equal "S1 · #4 · 1 / 5 · swipe to browse", position, slot.inspect
    end
  end

  test "another player's pack, one not opened, an unknown token, or a pack without the card is ignored: the card's first set" do
    add_a_tome
    player = accounts_players(:player)
    sign_in(player)
    tome = [ [ "a", in_tome("tin-soldier") ], [ "a", in_tome("blue-depths") ] ]
    foreign = create_pack(accounts_players(:moderator), cards: fixture_tier_ids, opened_at: 1.minute.ago)
    sealed = create_pack(player, cards: fixture_tier_ids)
    without = create_pack(player, cards: Array.new(5, catalog_card_seasons(:common_card_one).id), opened_at: 1.minute.ago)

    [ foreign.token, sealed.token, without.token, "nope", "" ].each do |token|
      get card_season_path(locale: :en, slug: "portal", number: 1, pack: token, slot: 4)

      assert_response :success, token
      assert_equal tome, navs, token
      assert_equal "S1 · #4 · 2 / 3 · swipe to browse", position, token
      assert_equal "/en/library/tome/action-1", css_select(".top-bar__phone-back").sole["href"], token
      assert_select ".card-detail__back", false
    end

    get card_season_path(locale: :en, slug: "portal", number: 1, pack: { token: foreign.token })
    assert_response :success
    assert_equal tome, navs

    # A visitor names no pack of theirs: the public card page.
    delete session_path(locale: :en)
    get card_season_path(locale: :en, slug: "portal", number: 1, pack: foreign.token)
    assert_select ".public-card"
  end

  # The slugs of the collection grid `params` asks for, every page, as the
  # library shows them.
  def grid_slugs(params, kind: nil, key: nil)
    (1..).each_with_object([]) do |page, slugs|
      get kind ? library_set_path(locale: :en, kind:, key:, **params, page:) : library_path(locale: :en, **params, page:)
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
    assert_equal "/en/library?state%5B%5D=all", css_select(".top-bar__phone-back").sole["href"]
    assert_equal "Grid", css_select(".top-bar__phone-back").sole.text.squish
    assert_select ".card-detail__back"

    get grid_detail(slugs[60], season.number, context)
    assert_equal "61 / 150", position[%r{\d+ / \d+}]
    assert_equal "/en/library?page=2&state%5B%5D=all", css_select(".top-bar__phone-back").sole["href"]

    # The newest held card opens the grid; the owned cards by default.
    get grid_detail(slugs[0], season.number, { q: "" })
    assert_equal [ [ "button", "disabled" ], [ "a", grid_detail(slugs[1], season.number, { q: "" }) ] ], navs
    assert_equal "1 / 3", position[%r{\d+ / \d+}]
    assert_equal "/en/library", css_select(".top-bar__phone-back").sole["href"]
    assert_select ".card-detail__card .card.card--l"
  end

  test "a filtered, searched grid is walked as shown, a set's grid too; a grid without the card, or an unknown set, is ignored" do
    season = publish_sets_draft
    filters = { state: %w[all missing], genre: %w[action], q: "Seed 1" }
    slugs = grid_slugs(filters)
    assert_operator slugs.size, :>, 2
    context = { genre: %w[action], q: "Seed 1", state: %w[all missing] }

    get grid_detail(slugs[1], season.number, context)
    assert_equal [ [ "a", grid_detail(slugs[0], season.number, context) ], [ "a", grid_detail(slugs[2], season.number, context) ] ], navs
    assert_equal "2 / #{slugs.size}", position[%r{\d+ / \d+}]
    assert_equal "/en/library?genre%5B%5D=action&q=Seed+1&state%5B%5D=all&state%5B%5D=missing", css_select(".top-bar__phone-back").sole["href"]
    # A visitor browsing a grid gets the detail, the card as the faded back.
    assert_select ".card-detail__back img[src*='back-standard']"
    assert_select ".public-card", false

    set_slugs = grid_slugs({ state: %w[all], rarity: %w[common rare] }, kind: "tome", key: "action-1")
    assert_operator set_slugs.size, :>, 2
    set_context = { key: "action-1", kind: "tome", q: "", rarity: %w[common rare], state: %w[all] }
    get grid_detail(set_slugs.last, season.number, set_context)
    assert_equal [ [ "a", grid_detail(set_slugs[-2], season.number, set_context) ], [ "button", "disabled" ] ], navs
    assert_equal "#{set_slugs.size} / #{set_slugs.size}", position[%r{\d+ / \d+}]
    assert_equal "/en/library/tome/action-1?rarity%5B%5D=common&rarity%5B%5D=rare&state%5B%5D=all", css_select(".top-bar__phone-back").sole["href"]

    # A grid that does not show the card, an unknown set or kind, a set
    # named in part: no context, so the visitor gets the public card page.
    [ { q: "nothing like it" }, { kind: "tome", key: "nope", q: "" }, { kind: "shelf", key: "action-1" }, { kind: "tome", q: "" } ].each do |other|
      get grid_detail(slugs[1], season.number, other)
      assert_response :success, other.inspect
      assert_select ".public-card", 1, other.inspect
    end
  end

  test "a grid filtered on new cards is walked against the watermark it was shown against, though showing it moved the player's" do
    season = publish_sets_draft
    player = accounts_players(:player)
    cards = Catalog::CardSeason.where(season_id: season.id).order(:number, :id).ids
    cards.first(3).each_with_index { |id, index| hold(player, id, 1, gained_at: (index + 1).hours.ago) }
    Game::PlayerState.where(player_id: player.id).update_all(collection_seen_up_to: 1.day.ago)
    sign_in(player)

    get library_path(locale: :en, state: %w[new])
    links = css_select(".collection-grid a.card-link").map { it["href"] }
    assert_equal 3, links.size
    # The grid posts the latest gain it showed: none of its cards is new any more.
    Game::PlayerState.where(player_id: player.id).update_all(collection_seen_up_to: Time.current)

    get links[1]
    assert_equal links.values_at(0, 2), navs.map(&:second)
    assert_equal "2 / 3", position[%r{\d+ / \d+}]
    assert_equal "/en/library?state%5B%5D=new", css_select(".top-bar__phone-back").sole["href"]

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
    add_a_tome
    publish_season_two_with_portal
    sign_in_viewer

    get card_season_path(locale: :en, slug: "tin-soldier", number: 1, grid: { q: "", state: %w[all] })
    assert_response :success
    assert_equal "S1 · #1 · 1 / 3 · swipe to browse", position
    assert_select ".top-bar__phone-back", false
  end

  test "a player's request costs nine queries, a visitor's two; a frame visit (◀ ▶) skips the top bar's" do
    player = accounts_players(:player)
    hold(player, catalog_card_seasons(:portal_one).id, 2)
    sign_in(player)

    # Player lookup, card detail, sets, neighbours, quantities, and the top
    # bar's three (reserve count, next pack, copies per tier), and the tab
    # bar's trades waiting.
    assert_request_queries(9) { get card_path(locale: :en, slug: "portal") }
    assert_response :success
    assert_equal [ "Copies", "2 copies" ], facts.last
    assert_select "#share-sheet"
    assert_request_queries(5) { get card_path(locale: :en, slug: "portal"), headers: { "Turbo-Frame" => "card-detail" } }
    assert_select "turbo-frame#card-detail .card-detail h1", "Portal"

    delete session_path(locale: :en)
    # The public card page: the card detail and its sets; no neighbours.
    assert_request_queries(2) { get card_path(locale: :en, slug: "portal") }
    assert_response :success
    assert_select ".public-card"
  end

  test "an opened pack in place of the set costs one query more, the collection grid five more" do
    player = accounts_players(:player)
    pack = create_pack(player, cards: fixture_tier_ids, opened_at: 1.minute.ago)
    sign_in(player)

    # The nine, the set's neighbours replaced by the pack and its two
    # neighbours' cards.
    assert_request_queries(10) { get pack_detail("blue-depths", pack, slot: 3) }
    assert_equal "S1 · #3 · 3 / 5 · swipe to browse", position

    # The set's neighbours replaced by the published season, the grid's
    # genres, the viewer's count of cards held (no state asked), the grid's
    # cards in order and its two neighbours' cards.
    assert_request_queries(13) { get card_season_path(locale: :en, slug: "blue-depths", number: 1, grid: { q: "" }) }
    assert_select ".card-detail__nav", 2
    # A state asked spares the count of cards held.
    assert_request_queries(12) { get card_season_path(locale: :en, slug: "blue-depths", number: 1, grid: { q: "", state: %w[all] }) }
  end

  test "no database id reaches the page" do
    add_a_tome
    player = accounts_players(:player)
    hold(player, catalog_card_seasons(:portal_one).id, 2)
    sign_in(player)
    ids = [ catalog_cards(:portal).id, catalog_card_seasons(:portal_one).id, catalog_seasons(:one).id, catalog_sets(:valve_one).id,
      catalog_card_texts(:portal_en).id, catalog_card_seasons(:common_card_one).id, catalog_card_seasons(:rare_card_one).id, player.id ]

    get in_tome("portal")

    assert_select ".card-detail [data-id]", false
    html = css_select(".card-detail").sole.to_html
    ids.each do |id|
      next if id < 10 # a season number, a year digit or a count would match

      assert_no_match(/\b#{id}\b/, html, "id #{id} on the page")
    end
    assert_no_match(/\b#{catalog_card_seasons(:portal_one).id}\b/, response.body)
  end
end
