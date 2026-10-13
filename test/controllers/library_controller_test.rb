require "test_helper"
require_relative "../support/catalog_seeds"
require_relative "../support/library_requests"

# The collection of the whole season: the top bar's unique cards, the
# kinds of sets the season holds and the sets of one kind as progress rows
# under "Whole season", the RAPPORT, the genre chips, the grid of owned faces
# and missing slots sixty to a page, the NOUVEAU tag and its watermark post;
# for a player, a visitor and a banned player; the queries of a request.
class LibraryControllerTest < ActionDispatch::IntegrationTest
  include CatalogSeeds
  include LibraryRequests

  setup do
    OmniAuth.config.test_mode = true
  end

  teardown do
    OmniAuth.config.mock_auth.delete(:steam)
    OmniAuth.config.test_mode = false
  end

  # The season's cards in grid order.
  def season_cards(season) = Catalog::CardSeason.where(season_id: season.id).where.not(rarity: nil).order(:number, :id).ids

  def title(card_season_id, locale = "en")
    Catalog::CardText.find_by!(card_id: Catalog::CardSeason.find(card_season_id).card_id, locale:).title
  end

  def year(card_season_id) = Catalog::CardSeason.find(card_season_id).card.release_date.year

  # The season's cards whose main theme is `theme`.
  def main_theme_cards(season, theme) = Catalog::CardSeason.where(season_id: season.id, main_theme: theme).ids

  # The set progress rows as [ name, "owned/total" ], in order.
  def set_rows
    css_select(".collection-sets .set-row").map { [ it.at_css(".set-row__name").text, it.at_css(".set-row__count").text ] }
  end

  def current_row = css_select(".collection-sets .set-row[aria-current=page] .set-row__name").sole.text

  # The grid's slots: [ :owned, title, "xn", "New" | nil ] or [ :missing, title, year ].
  def slots
    css_select(".collection-grid > li.collection-slot").map do |slot|
      if (card = slot.at_css(".card"))
        [ :owned, card.at_css(".card__title").text, slot.at_css(".collection-slot__copies").text, slot.at_css(".collection-slot__new")&.text ]
      else
        [ :missing, slot.at_css(".missing-slot__title").text, slot.at_css(".missing-slot__year").text.to_i ]
      end
    end
  end

  def report
    css_select(".report--panel .report__row").to_h { [ it.at_css("dt").text.strip, it.at_css("dd").text ] }
  end

  test "a player sees their unique cards, the themes' progress, the RAPPORT and the first sixty cards of the season" do
    season = publish_sets_draft
    player = accounts_players(:player)
    cards = season_cards(season)
    # The first three of the grid (numbers are shuffled at publication), and
    # a card of a theme held at 0.
    first, second, third = cards.first(3)
    hold(player, first, 1)
    hold(player, second, 3)
    hold(player, third, 1)
    hold(player, (set_members(season, "rpg") - cards.first(3)).first, 0)
    themes = %w[horror pirates roguelike rpg].map { (set_members(season, it) & [ first, second, third ]).size }
    sign_in(player)

    get library_path(locale: :en, state: %w[all])

    assert_response :success
    assert_select "title", "Collection"
    assert_select ".top-bar__start > a.button--secondary[href='/en']", "Bridge"
    assert_select ".top-bar__title", "Collection"
    assert_select ".top-bar__end .collection-status" do
      assert_select ".collection-status__label[aria-hidden=true]", "Unique cards:"
      assert_select ".collection-status__value[aria-hidden=true]", "3 / 150"
      assert_select ".visually-hidden", "3 unique cards out of 150"
      assert_select "progress.collection-status__bar[value='3'][max='150'][aria-hidden=true]"
    end
    assert_select ".top-bar .rarity-counter, .top-bar .packs-chip", false
    assert_select ".top-bar .player-chip"
    assert_select "h1", "Whole season"

    assert_select ".collection-sets__kicker", "Sets"
    assert_equal [ [ "Themes", "/en/library", "true" ], [ "UFOs", "/en/library?kind=ufo", nil ] ],
      css_select(".collection-kinds a.collection-kind").map { [ it.text, it["href"], it["aria-current"] ] }
    assert_equal [ [ "Whole season", "3/150" ], [ "Horror", "#{themes[0]}/16" ], [ "Pirates", "#{themes[1]}/8" ],
      [ "Roguelike", "#{themes[2]}/119" ], [ "RPG", "#{themes[3]}/44" ] ], set_rows
    assert_equal "Whole season", current_row
    assert_equal [ "/en/library", "/en/library/theme/horror", "/en/library/theme/pirates", "/en/library/theme/roguelike", "/en/library/theme/rpg" ],
      css_select(".collection-sets .set-row").map { it["href"] }
    assert_select ".collection-sets .set-row .visually-hidden", "#{themes[1]} #{themes[1] == 1 ? "card" : "cards"} owned out of 8"
    assert_select ".collection-sets .series-nav", false

    copies = Hash.new(0)
    Catalog::CardSeason.where(id: [ first, second, third ]).pluck(:id, :rarity).each { |id, rarity| copies[rarity] += { first => 1, second => 3, third => 1 }.fetch(id) }
    tiers = Catalog::Rarity::TIERS.values.to_h { [ I18n.t("catalog.rarity.#{it}", locale: :en), copies[it.to_s].to_s ] }
    assert_equal({ "Total cards" => "5", "Duplicates" => "2" }.merge(tiers), report)
    assert_select ".report--fold summary .report__line", "5 cards · 2 duplicates"
    assert_select ".report--fold .report__row dt", "Unique cards"

    assert_equal [ "Owned", "All", "Missing", "New", "Duplicates" ], css_select("[data-group=state] .filter-chip__text").map(&:text)
    assert_equal [ "All" ], css_select("[data-group=state] .filter-chip__box[checked]").map { it.parent.at_css(".filter-chip__text").text }
    expected = cards.first(60).map do |id|
      case id
      when first, third then [ :owned, title(id), "x1", nil ]
      when second then [ :owned, title(id), "x3", nil ]
      else [ :missing, title(id), year(id) ]
      end
    end
    assert_equal expected, slots
    assert_select ".collection-grid .card.card--m", expected.count { it.first == :owned }
    assert_select ".collection-slot__copies[aria-hidden=true] + .visually-hidden", "3 copies"
    assert_select ".missing-slot svg.pixel-icon.missing-slot__icon"
    assert_select ".missing-slot .visually-hidden", { count: 60 - expected.count { it.first == :owned }, text: "Missing card" }
    # Every face and missing slot leads to its card's detail in this season,
    # carrying the grid's filters and search, so the detail walks this grid.
    slugs = Catalog::CardSeason.where(id: cards.first(60)).includes(:card).index_by(&:id).transform_values { it.card.slug }
    links = css_select(".collection-grid > li > a.card-link")
    assert_equal cards.first(60).map { |id|
      "/en/cards/#{slugs.fetch(id)}/seasons/#{season.number}?grid%5Bq%5D=&grid%5Bstate%5D%5B%5D=all"
    }, links.map { it["href"] }
    assert links.all? { it["data-turbo-prefetch"] == "false" }
    assert_select "a.card-link .collection-slot__copies", false
    assert_select ".collection-pages[aria-label=?]", "Pages of cards" do
      assert_select "[aria-current=page]", "Page 1"
      assert_select "a[href=?]:not([rel])", "/en/library?state%5B%5D=all&page=2", "Page 2"
      assert_select "a[rel=next][href=?][aria-label=?]", "/en/library?state%5B%5D=all&page=2", "Next page"
      assert_select "a[rel=prev]", false
    end
    assert_select "[data-controller=collection-seen]", false
    assert_select "[style]", false
  end

  test "a held card's link and a missing one's carry the grid's filters and search; a set's page adds its set" do
    season = publish_sets_draft
    player = accounts_players(:player)
    held, missing = season_cards(season).first(2)
    hold(player, held, 1)
    sign_in(player)
    query = ->(params) { { grid: params }.to_query }
    href = ->(id, params) { "/en/cards/#{Catalog::CardSeason.find(id).card.slug}/seasons/#{season.number}?#{query.(params)}" }

    get library_path(locale: :en, state: %w[all], rarity: %w[nope], q: " seed ", kind: "publisher", page: 1)

    context = { state: %w[all], rarity: %w[nope], q: "seed" }
    assert_select ".collection-grid a.card-link[href=?] .card", href.(held, context)
    assert_select ".collection-grid a.card-link[href=?] .missing-slot", href.(missing, context)

    # The owned cards by default: only the search, always there.
    get library_path(locale: :en)
    assert_equal [ href.(held, { q: "" }) ], css_select(".collection-grid a.card-link").map { it["href"] }

    get library_set_path(locale: :en, kind: "theme", key: "pirates", state: %w[all], genre: %w[horror])
    assert_equal [ "?#{query.({ genre: %w[horror], key: "pirates", kind: "theme", q: "", state: %w[all] })}" ] * 8,
      css_select(".collection-grid a.card-link").map { it["href"][/\?.*/] }
  end

  test "a grid filtered on new cards: its links carry the watermark it was shown against, at one query more; no other grid's do" do
    season = publish_sets_draft
    player = accounts_players(:player)
    first, second = season_cards(season).first(2)
    hold(player, first, 1, gained_at: 2.hours.ago)
    hold(player, second, 1, gained_at: 1.minute.ago)
    watermark = Time.utc(2026, 10, 8, 9, 30, 15.123456r)
    Game::PlayerState.where(player_id: player.id).update_all(collection_seen_up_to: watermark)
    sign_in(player)

    # The sixteen of a player's whole season, the state asked sparing the
    # count read again from the query cache and adding the watermark.
    assert_request_queries(17) { get library_path(locale: :en, state: %w[new duplicates]) }
    seen = css_select(".collection-grid a.card-link").map { Rack::Utils.parse_nested_query(URI(it["href"]).query).dig("grid", "seen") }
    assert_equal [ "2026-10-08T09:30:15.123456Z" ] * 2, seen

    get library_path(locale: :en, state: %w[owned])
    assert_select ".collection-grid a.card-link", 2
    assert_select ".collection-grid a.card-link[href*=seen]", false

    # A player who has seen no card yet: a watermark before any gain, so
    # the detail still finds every card new once the grid has moved it.
    Game::PlayerState.where(player_id: player.id).update_all(collection_seen_up_to: nil)
    get library_path(locale: :en, state: %w[new])
    seen = css_select(".collection-grid a.card-link").map { Rack::Utils.parse_nested_query(URI(it["href"]).query).dig("grid", "seen") }
    assert_equal [ "1970-01-01T00:00:00.000000Z" ] * 2, seen
  end

  test "the grid's pages: sixty cards each, the rest on the last, past it the empty line" do
    season = publish_sets_draft
    cards = season_cards(season)

    get library_path(locale: :en, page: 2)
    assert_equal cards[60, 60].map { title(it) }, slots.map(&:second)
    assert_select ".collection-pages a[rel=prev][href='/en/library?page=1']"

    get library_path(locale: :en, page: 3)
    assert_equal 30, slots.size
    assert_select ".collection-pages a[rel=next]", false

    get library_path(locale: :en, page: 9)
    assert_response :success
    assert_empty slots
    assert_select ".collection-grid__empty", "No more cards here: the grid ends on an earlier page. Go back to the last page."
    assert_select ".collection-pages a[rel=prev][href='/en/library?page=3']"

    [ "abc", "99999999999999999999" ].each do |page|
      get library_path(locale: :en, page:)
      assert_response :success
    end
    get library_path(locale: :en, page: "abc")
    assert_equal 60, slots.size
  end

  test "a visitor sees every slot missing, no NOUVEAU and the Steam sign-in image, without a holdings query" do
    season = publish_sets_draft
    hold(accounts_players(:player), season_cards(season).first, 1, gained_at: 1.minute.ago)

    assert_no_queries_match(/game_holdings|game_player_states/) { get library_path(locale: :en) }

    assert_response :success
    assert_equal season_cards(season).first(60).map { [ :missing, title(it), year(it) ] }, slots
    assert_select ".collection-slot__new, [data-controller=collection-seen]", false
    assert_select ".collection-status__value", "0 / 150"
    assert_select ".top-bar__end form.steam-sign-in input[name=origin][value='/en/library']"
    assert_equal [ [ "Whole season", "0/150" ], [ "Horror", "0/16" ], [ "Pirates", "0/8" ], [ "Roguelike", "0/119" ], [ "RPG", "0/44" ] ], set_rows
    assert_equal({ "Total cards" => "0", "Duplicates" => "0" }, report.first(2).to_h)
  end

  test "a player banned since signing in sees the collection as a visitor, with no ownership query" do
    season = publish_sets_draft
    player = accounts_players(:player)
    hold(player, season_cards(season).first, 1, gained_at: 1.minute.ago)
    sign_in(player)
    player.update_columns(banned_at: Time.current)

    assert_no_queries_match(/game_holdings|game_player_states/) do
      # The visitor's nine, after the lookup that finds the ban.
      assert_request_queries(1 + 9) { get library_path(locale: :en) }
    end

    assert_response :success
    assert_equal :missing, slots.first.first
    assert_select ".collection-slot__new", false
    assert_nil session[:player_id]
  end

  test "cards gained since the watermark are new; the page carries the latest gain shown, posted once rendered" do
    season = publish_sets_draft
    player = accounts_players(:player)
    first, second, third, fourth = season_cards(season).first(4)
    older = 2.hours.ago.change(usec: 111_111)
    latest = 1.hour.ago.change(usec: 654_321)
    hold(player, first, 2, gained_at: older)
    hold(player, second, 1, gained_at: latest)
    hold(player, third, 1)
    hold(player, fourth, 1, gained_at: 3.hours.ago)
    Game::PlayerState.where(player_id: player.id).update_all(collection_seen_up_to: 150.minutes.ago)
    sign_in(player)

    get library_path(locale: :fr)

    # Owned cards only, newest gained first, the one never gained last.
    assert_equal [ [ :owned, title(second, "fr"), "x1", "Nouveau" ], [ :owned, title(first, "fr"), "x2", "Nouveau" ],
      [ :owned, title(fourth, "fr"), "x1", nil ], [ :owned, title(third, "fr"), "x1", nil ] ], slots
    assert_select "div[hidden][data-controller=collection-seen][data-collection-seen-url-value='/fr/library/seen']" do |element|
      assert_equal latest.utc.iso8601(6), element.first["data-collection-seen-up-to-value"]
    end

    Game::MarkCollectionSeen.new.call(player:, up_to: latest)
    get library_path(locale: :fr)

    assert_select ".collection-slot__new", false
    assert_select "[data-controller=collection-seen]", false
  end

  test "the page writes nothing: the watermark moves only by its POST" do
    season = publish_sets_draft
    player = accounts_players(:player)
    hold(player, season_cards(season).first, 1, gained_at: 1.minute.ago)
    sign_in(player)

    assert_no_changes -> { Game::PlayerState.find_by!(player_id: player.id).attributes } do
      get library_path(locale: :en)
      get library_set_path(locale: :en, kind: "theme", key: "rpg")
    end
  end

  test "a new card hidden by the filters carries no post; shown first, it carries one" do
    season = publish_sets_draft
    player = accounts_players(:player)
    hold(player, season_cards(season).last, 1, gained_at: 1.minute.ago)
    sign_in(player)

    get library_path(locale: :en, state: %w[missing])
    assert_select "[data-controller=collection-seen]", false

    get library_path(locale: :en, state: %w[all], page: 2)
    assert_select ".collection-slot__new", false
    assert_select "[data-controller=collection-seen]", false

    # Newest gained first: on the first page, tagged, with its post.
    get library_path(locale: :en, state: %w[all])
    assert_select ".collection-slot__new", "New"
    assert_select "[data-controller=collection-seen]"
  end

  [ nil, "", "nope", [ "ufo" ], "publisher" ].each do |kind|
    test "a kind of #{kind.inspect} lists the themes" do
      publish_sets_draft

      get library_path(locale: :en), params: { kind: }.compact

      assert_response :success
      assert_select ".collection-kind[aria-current=true]", "Themes"
      assert_equal 5, set_rows.size
    end
  end

  test "the UFOs list their set, with its progress" do
    season = publish_sets_draft
    player = accounts_players(:player)
    hold(player, set_members(season, "ufos").first, 1)
    sign_in(player)

    get library_path(locale: :fr, kind: "ufo")
    assert_select ".collection-kind[aria-current=true]", "OVNI"
    assert_equal [ [ "Toute la saison", "1/150" ], [ "Les OVNI", "1/15" ] ], set_rows
    assert_equal "Toute la saison", current_row
    assert_equal [ "/fr/library?kind=ufo", "/fr/library/ufo/ufos" ], css_select(".collection-sets .set-row").map { it["href"] }
  end

  test "franchises and studios have their tabs and list their sets by name, in English and French" do
    publish_franchises_and_studios_draft

    get library_path(locale: :en)
    assert_equal [ "Themes", "Franchises", "Studios", "UFOs" ], css_select(".collection-kinds a.collection-kind").map(&:text)

    get library_path(locale: :en, kind: "franchise")
    assert_select ".collection-kind[aria-current=true]", "Franchises"
    assert_equal [ [ "Whole season", "0/24" ], [ "Tom Clancy", "0/3" ] ], set_rows
    assert_equal "/en/library/franchise/tom-clancy", css_select(".collection-sets .set-row").last["href"]

    get library_path(locale: :fr, kind: "studio")
    assert_select ".collection-kind[aria-current=true]", "Studios"
    assert_equal [ [ "Toute la saison", "0/24" ], [ "CAPCOM", "0/3" ] ], set_rows
    assert_equal [ "Thèmes", "Franchises", "Studios", "OVNI" ], css_select(".collection-kinds a.collection-kind").map(&:text)
  end

  test "the hall of fame has its tab and lists its sets in their fixed order, by name, in English and French" do
    publish_hall_of_fame_draft

    get library_path(locale: :en)
    assert_equal [ "Themes", "Hall of fame" ], css_select(".collection-kinds a.collection-kind").map(&:text)

    get library_path(locale: :en, kind: "hall_of_fame")
    assert_select ".collection-kind[aria-current=true]", "Hall of fame"
    assert_equal [ [ "Whole season", "0/24" ], [ "The Untouchables", "0/2" ], [ "Hidden Gems", "0/1" ], [ "The Unloved", "0/2" ],
      [ "The Phenomena", "0/2" ] ], set_rows
    assert_equal "/en/library/hall_of_fame/mal-aimes", css_select(".collection-sets .set-row")[3]["href"]

    get library_path(locale: :fr, kind: "hall_of_fame")
    assert_select ".collection-kind[aria-current=true]", "Panthéon"
    assert_equal [ "Toute la saison", "Les Intouchables", "Les Pépites", "Les Mal-aimés", "Les Phénomènes" ], set_rows.map(&:first)
  end

  test "a season published before themes keeps its kinds' tabs, opening on the first, each kind in its order" do
    seed_published_sets([
      [ "best_of_year", "2011", { "year" => 2011 } ], [ "publisher", "valve", { "publisher" => "Valve" } ],
      [ "tome", "action-1", { "genre" => "action", "volume" => 1, "volumes" => 1 } ], [ "best_of_year", "2015", { "year" => 2015 } ]
    ])

    get library_path(locale: :en)
    assert_equal [ [ "Tomes", "/en/library?kind=tome", "true" ], [ "Publishers", "/en/library?kind=publisher", nil ],
      [ "Best rated of the year", "/en/library?kind=best_of_year", nil ] ],
      css_select(".collection-kinds a.collection-kind").map { [ it.text, it["href"], it["aria-current"] ] }
    assert_equal [ [ "Whole season", "0/0" ], [ "Action · Tome 1", "0/0" ] ], set_rows

    get library_path(locale: :fr, kind: "best_of_year")
    assert_equal [ "Toute la saison", "Les mieux notés de 2015", "Les mieux notés de 2011" ], set_rows.map(&:first)

    get library_path(locale: :en, kind: "publisher")
    assert_equal [ "Whole season", "Valve" ], set_rows.map(&:first)
    assert_equal [ "Valve" ], css_select("[data-group=sets] .filter-chip__text").map(&:text)

    get library_path(locale: :en, kind: "theme")
    assert_select ".collection-kind[aria-current=true]", "Tomes"
  end

  test "a season without sets says so" do
    seed_published_sets([])

    get library_path(locale: :en)

    assert_response :success
    assert_select ".collection-kinds a", false
    assert_equal [ [ "Whole season", "0/0" ] ], set_rows
    assert_select ".collection-sets__empty", "No theme in this season."
    assert_select ".collection-sets .series-nav", false
    assert_select ".collection-grid__empty", "Nothing matches these filters."
    assert_select ".collection-pages", false
  end

  test "120 tomes come fifty to a list page (shelf), kept by the rows' links; past the last the list says so" do
    seed_published_sets((1..120).map { |volume| [ "tome", "action-#{volume}", { "genre" => "action", "volume" => volume, "volumes" => 120 } ] })

    get library_path(locale: :en)
    assert_equal 51, set_rows.size
    assert_equal "Action · Tome 1", set_rows.second.first
    assert_select ".collection-sets .series-nav a[aria-current=page]", "1"
    assert_select ".collection-sets .series-nav a[href='/en/library?shelf=2']", minimum: 1
    assert_select ".collection-sets .series-nav a[href]:not([data-turbo-prefetch=false])", false

    get library_path(locale: :en, shelf: 3)
    assert_equal [ "Whole season", "Action · Tome 101" ], set_rows.first(2).map(&:first)
    assert_equal 21, set_rows.size
    assert_equal "/en/library?kind=tome&shelf=3", css_select(".collection-sets .set-row").first["href"]
    assert_equal "/en/library/tome/action-101?shelf=3", css_select(".collection-sets .set-row")[1]["href"]

    get library_path(locale: :en, shelf: 9)
    assert_response :success
    assert_equal 1, set_rows.size
    assert_select ".collection-sets__empty", "This list ends on an earlier page."
    assert_select ".collection-sets .series-nav a[href='/en/library?shelf=3']", minimum: 1
  end

  test "the genre chips filter the grid, OR within the group; an unknown genre is ignored" do
    season = publish_sets_draft
    roguelike = main_theme_cards(season, "roguelike")
    rpg = main_theme_cards(season, "rpg")

    get library_path(locale: :fr, kind: "ufo", shelf: 1, state: %w[all])
    assert_equal [ "Horreur", "Roguelike", "RPG" ], css_select("[data-group=genre] .filter-chip__text").map(&:text)
    assert_equal [ "genre[]" ], css_select("[data-group=genre] input").map { it["name"] }.uniq
    assert_equal [ "ufo" ], css_select("form.filters input[name=kind]").map { it["value"] }

    get library_path(locale: :en, genre: [ "rpg" ], state: %w[all])
    assert_equal [ "RPG" ], css_select("[data-group=genre] .filter-chip__box[checked]").map { it.parent.text.strip }
    assert_equal season_cards(season).select { it.in?(rpg) }.map { title(it) }, slots.map(&:second)

    get library_path(locale: :en, genre: [ "rpg", "roguelike" ], state: %w[all])
    assert_equal season_cards(season).select { it.in?(rpg + roguelike) }.first(60).map { title(it) }, slots.map(&:second)

    get library_path(locale: :en, genre: [ "rpg" ], state: %w[all], page: 2)
    assert_empty slots
    assert_select ".collection-grid__empty", "No more cards here: the grid ends on an earlier page. Go back to the last page."

    [ "strategy", [ "strategy" ] ].each do |genre|
      get library_path(locale: :en), params: { genre: }
      assert_response :success
      assert_select ".filters__count[hidden]"
      assert_equal 60, slots.size
    end
  end

    test "French copy" do
    season = publish_sets_draft
    player = accounts_players(:player)
    first = season_cards(season).first
    hold(player, first, 1, gained_at: 1.minute.ago)
    sign_in(player)

    get library_path(locale: :fr, state: %w[all])

    assert_select ".collection-status__label", "Cartes uniques :"
    assert_select ".collection-status .visually-hidden", "1 carte unique sur 150"
    assert_select ".report--panel .report__title", "Rapport"
    assert_select ".report--fold .report__line", "1 carte · 0 doublon"
    assert_equal [ "Cartes totales", "Doublons" ], css_select(".report--panel .report__row dt").first(2).map { it.text.strip }
    assert_select ".collection-slot__new", "Nouveau"
    assert_select ".collection-slot__copies + .visually-hidden", "1 exemplaire"
    assert_select ".missing-slot .visually-hidden", { minimum: 1, text: "Carte manquante" }
    assert_select ".collection-pages[aria-label=?] a[rel=next][aria-label=?]", "Pages de cartes", "Page suivante"
  end

  test "with no season published the collection says so" do
    catalog_seasons(:one).update_columns(status: "draft", published_at: nil)

    get library_path(locale: :en)

    assert_response :success
    assert_select ".collection-none p.panel", "No season of cards is published yet."
    assert_select ".collection, .collection-status", false

    get library_path(locale: :fr)

    assert_select ".collection-none p.panel", "Aucune saison de cartes n'est publiée pour l'instant."
  end

  test "no set or card-season id reaches the page" do
    season = publish_sets_draft
    player = accounts_players(:player)
    hold(player, season_cards(season).first, 2, gained_at: 1.minute.ago)
    sign_in(player)
    ids = Catalog::Set.where(season_id: season.id).ids + Catalog::CardSeason.where(season_id: season.id).ids

    get library_path(locale: :en)

    assert_select ".collection [data-id]", false
    assert_equal %w[collection-sets-title collection-report-title collection-search collection-results], css_select(".collection [id]").map { it["id"] }
    html = css_select(".collection").sole.to_html
    ids.each do |id|
      assert_no_match(/\b#{id}\b/, html.gsub(/Tome \d+|\d+\/\d+|\d+ (cards?|copies|copy|duplicates?) |out of \d+|\b(19|20)\d\d\b|x\d+|seed-\d+-\d+|data-card-art-(width|height)-value="\d+"|width="\d+"|height="\d+"|viewbox="[\d ]+"|\?(page|shelf)=\d+|\/seasons\/\d+|value="\d+"|max="\d+"|[Ss]eason \d+|#\d+|Page<\/span> \d+|<dd>\d+<\/dd>|[MmHhVvZz][\d.-]+/, ""))
    end
  end

  test "a player's request costs sixteen queries, a visitor's nine" do
    season = publish_sets_draft
    player = accounts_players(:player)
    hold(player, season_cards(season).first, 1, gained_at: 1.minute.ago)
    sign_in(player)

    # Player lookup, published season; the list: the kinds the season holds,
    # count, page, totals, progress; the grid: genres, count (the season's cards, read again from
    # the query cache by the top bar; filtered by state it is its own query),
    # page, card views, the player's slots; the figures: unique cards,
    # copies per tier; the tab bar's trades waiting. No tome per card: the
    # links carry the grid, which the detail reads itself.
    assert_request_queries(16) { get library_path(locale: :en) }

    delete session_path(locale: :en)
    # The same without the lookup, the progress, the slots, the unique cards
    # and the copies per tier.
    assert_request_queries(9) { get library_path(locale: :en) }
  end

  test "the collection opens on the owned cards, newest gained first, FILTRES folded with no count" do
    season = publish_sets_draft
    player = accounts_players(:player)
    first, second, third = season_cards(season).first(3)
    hold(player, first, 1, gained_at: 3.hours.ago)
    hold(player, second, 2, gained_at: 1.hour.ago)
    hold(player, third, 1)
    sign_in(player)

    get library_path(locale: :en)

    assert_equal [ second, first, third ].map { [ :owned, title(it), nil ] }, slots.map { [ it[0], it[1], nil ] }
    assert_select "form.filters[method=get][data-controller=collection-filters][data-turbo-frame=collection-results]"
    assert_select "details.filters__zone:not([open]) summary", /Filters/
    assert_select ".filters__count[hidden]"
    assert_select ".filters__clear[hidden]"
    assert_select "turbo-frame#collection-results[target=_top] .collection-grid"
    assert_select "input[type=search][name=q]#collection-search"
    assert_equal [ "Owned" ], css_select("[data-group=state] .filter-chip__box[checked]").map { it.parent.text.strip }
    assert_equal [ "Common", "Uncommon", "Rare", "Epic", "Legendary" ], css_select("[data-group=rarity] .filter-chip__text").map(&:text)
    assert_equal [ "Horror", "Pirates", "Roguelike", "RPG" ], css_select("[data-group=sets] .filter-chip__text").map(&:text)
  end

  test "the missing state shows the empty slots naming the game; owned plus missing is every slot" do
    season = publish_sets_draft
    player = accounts_players(:player)
    cards = season_cards(season)
    hold(player, cards.first, 1)
    sign_in(player)

    get library_path(locale: :en, state: %w[missing])
    assert_equal cards.drop(1).first(60).map { [ :missing, title(it), year(it) ] }, slots
    assert_select ".filters__count:not([hidden])", /1/
    assert_select "details.filters__zone[open]"
    assert_select ".filters__clear:not([hidden])[href=?]", "/en/library"

    get library_path(locale: :en, state: %w[owned missing])
    assert_equal :owned, slots.first.first
    assert_equal 60, slots.size
    assert_select ".filters__count", /2/
  end

  test "new and duplicates states; an unknown state is ignored" do
    season = publish_sets_draft
    player = accounts_players(:player)
    first, second, third = season_cards(season).first(3)
    hold(player, first, 2, gained_at: 2.hours.ago)
    hold(player, second, 1, gained_at: 1.minute.ago)
    hold(player, third, 3)
    Game::PlayerState.where(player_id: player.id).update_all(collection_seen_up_to: 1.hour.ago)
    sign_in(player)

    get library_path(locale: :en, state: %w[new])
    assert_equal [ title(second) ], slots.map(&:second)

    get library_path(locale: :en, state: %w[duplicates])
    assert_equal [ title(first), title(third) ], slots.map(&:second)

    get library_path(locale: :en, state: %w[new duplicates])
    assert_equal [ second, first, third ].map { title(it) }, slots.map(&:second)

    get library_path(locale: :en, state: %w[bogus])
    assert_equal 3, slots.size
  end

  test "two genre chips show either genre; a rarity chip then narrows to both" do
    season = publish_sets_draft
    player = accounts_players(:player)
    cards = season_cards(season)
    rpg = main_theme_cards(season, "rpg")
    roguelike = main_theme_cards(season, "roguelike")
    sample = (rpg.first(6) + roguelike.first(6))
    sample.each { hold(player, it, 1) }
    sign_in(player)

    get library_path(locale: :en, genre: %w[rpg])
    assert_equal rpg.first(6).map { title(it) }.sort, slots.map(&:second).sort

    get library_path(locale: :en, genre: %w[rpg roguelike])
    assert_equal sample.size, slots.size

    rarity = Catalog::CardSeason.where(id: sample).pick(:rarity)
    both = Catalog::CardSeason.where(id: sample, rarity:).count
    get library_path(locale: :en, genre: %w[rpg roguelike], rarity: [ rarity ])
    assert_equal both, slots.size
    assert_operator both, :<, sample.size
    assert_select ".filters__count", /3/
  end

  test "the set chips filter the whole season's cards, OR within the group" do
    season = publish_sets_draft
    player = accounts_players(:player)
    a = set_members(season, "horror").first(3)
    b = set_members(season, "rpg").first(2)
    (a + b).each { hold(player, it, 1) }
    sign_in(player)

    get library_path(locale: :en, sets: %w[theme:horror theme:rpg])
    assert_equal 5, slots.size
    assert_equal [ "Horror", "RPG" ], css_select("[data-group=sets] .filter-chip__box[checked]").map { it.parent.text.strip }

    get library_path(locale: :en, sets: %w[theme:rpg])
    assert_equal 2, slots.size
  end

  test "a search over title and publisher narrows the grid with the other filters; an empty result shows the empty-filter line" do
    season = publish_sets_draft
    player = accounts_players(:player)
    titled = Catalog::CardSeason.where(season_id: season.id).joins(card: :texts).where(catalog_card_texts: { locale: "en", title: "Seed 5" }).pick(:id)
    published = Catalog::CardSeason.where(season_id: season.id).joins(:card).where(catalog_cards: { publisher: "P" }).ids
    ([ titled ] + published).each { hold(player, it, 1) }
    sign_in(player)

    get library_path(locale: :en, q: "seed 5")
    assert_equal "Seed 5", slots.first.second
    assert_select "input[name=q][value=?]", "seed 5"
    assert_select ".filters__clear:not([hidden])"

    get library_path(locale: :en, q: "P", state: %w[all])
    assert_operator slots.size, :>=, 5

    get library_path(locale: :en, q: "seed 5", state: %w[missing])
    assert slots.any?
    assert slots.all? { it.first == :missing && it.second.start_with?("Seed 5") && it.second != "Seed 5" }

    get library_path(locale: :en, q: "zzzz")
    assert_empty slots
    assert_select ".collection-grid__empty", "Nothing matches these filters."
    assert_select ".collection-pages", false

    get library_path(locale: :en, q: "%")
    assert_empty slots
  end

  test "a visitor, and a player owning nothing, open on every slot; owned shows none" do
    season = publish_sets_draft
    get library_path(locale: :en)
    assert_equal 60, slots.size
    assert_equal [ "All" ], css_select("[data-group=state] .filter-chip__box[checked]").map { it.parent.text.strip }
    assert_select ".filters__count[hidden]"
    assert_select "[data-group=state][data-default=all]"
    assert_select "form.filters[role=search]"
    assert_select "turbo-frame#collection-results p[role=status]", "150 cards shown."

    # Asking "all" explicitly is the default of this viewer: no filter on.
    get library_path(locale: :en, state: %w[all])
    assert_select ".filters__count[hidden]"
    assert_select ".filters__clear[hidden]"

    get library_path(locale: :en, state: %w[owned])
    assert_empty slots
    assert_select "turbo-frame#collection-results p[role=status]", "No card shown."

    get library_path(locale: :en, state: %w[missing])
    assert_equal 60, slots.size

    sign_in(accounts_players(:player))
    get library_path(locale: :en)
    assert_equal season_cards(season).first(60).map { [ :missing, title(it), year(it) ] }, slots
  end

  test "the filters apply inside a set page and the list keeps its kind" do
    season = publish_sets_draft
    player = accounts_players(:player)
    members = set_members(season, "roguelike")
    hold(player, members[3], 1)
    sign_in(player)

    get library_set_path(locale: :en, kind: "theme", key: "roguelike", rarity: Catalog::Rarity::TIERS.values.map(&:to_s))
    assert_equal [ title(members[3]) ], slots.map(&:second)
    assert_select ".filters__clear[href=?]", "/en/library/theme/roguelike"
  end
end
