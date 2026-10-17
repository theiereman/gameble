require "test_helper"
require_relative "../support/catalog_seeds"
require_relative "../support/game_sets"
require_relative "../support/library_requests"
require_relative "../support/steam_sign_in"

# The collection. Its entry: the sets in progress, closest first, those to
# discover, the search over every set. Its grid of the whole season: the top
# bar's unique cards, the kinds of sets the season holds and the sets of one
# kind as progress rows under "Whole season", the RAPPORT, the genre chips,
# the grid of owned faces and missing slots sixty to a page, the NOUVEAU tag
# and its watermark post; for a player, a visitor and a banned player; the
# queries of a request.
class LibraryControllerTest < ActionDispatch::IntegrationTest
  include CatalogSeeds
  include GameSets
  include LibraryRequests
  include SteamSignIn

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

  def owned_slots
    slots.select { it.first == :owned }
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

    get library_cards_path(locale: :en, state: %w[all])

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
    assert_equal [ [ "Themes", "/en/library/cards", "true" ], [ "UFOs", "/en/library/cards?kind=ufo", nil ] ],
      css_select(".collection-kinds a.collection-kind").map { [ it.text, it["href"], it["aria-current"] ] }
    assert_equal [ [ "Whole season", "3/150" ], [ "Horror", "#{themes[0]}/16" ], [ "Pirates", "#{themes[1]}/8" ],
      [ "Roguelike", "#{themes[2]}/119" ], [ "RPG", "#{themes[3]}/44" ] ], set_rows
    assert_equal "Whole season", current_row
    assert_equal [ "/en/library/cards", "/en/library/theme/horror", "/en/library/theme/pirates", "/en/library/theme/roguelike", "/en/library/theme/rpg" ],
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
      assert_select "a[href=?]:not([rel])", "/en/library/cards?state%5B%5D=all&page=2", "Page 2"
      assert_select "a[rel=next][href=?][aria-label=?]", "/en/library/cards?state%5B%5D=all&page=2", "Next page"
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

    get library_cards_path(locale: :en, state: %w[all], rarity: %w[nope], q: " seed ", kind: "studio", page: 1)

    context = { state: %w[all], rarity: %w[nope], q: "seed" }
    assert_select ".collection-grid a.card-link[href=?] .card", href.(held, context)
    view = Catalog::CardViews.call([ held ], locale: :en).fetch(held)
    label = "#{view.title}, #{view.year}, #{I18n.t("catalog.rarity.#{view.rarity}", locale: :en)}, season #{season.number}"
    assert_select ".collection-grid a.card-link[href=?][aria-label=?]", href.(held, context), label
    assert_select ".collection-grid a.card-link[href=?] .missing-slot", href.(missing, context)

    # Every slot by default, the held card first: only the search, always there.
    get library_cards_path(locale: :en)
    assert_equal [ href.(held, { q: "" }), href.(missing, { q: "" }) ], css_select(".collection-grid a.card-link").first(2).map { it["href"] }

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
    assert_request_queries(17) { get library_cards_path(locale: :en, state: %w[new duplicates]) }
    seen = css_select(".collection-grid a.card-link").map { Rack::Utils.parse_nested_query(URI(it["href"]).query).dig("grid", "seen") }
    assert_equal [ "2026-10-08T09:30:15.123456Z" ] * 2, seen

    get library_cards_path(locale: :en, state: %w[owned])
    assert_select ".collection-grid a.card-link", 2
    assert_select ".collection-grid a.card-link[href*=seen]", false

    # A player who has seen no card yet: a watermark before any gain, so
    # the detail still finds every card new once the grid has moved it.
    Game::PlayerState.where(player_id: player.id).update_all(collection_seen_up_to: nil)
    get library_cards_path(locale: :en, state: %w[new])
    seen = css_select(".collection-grid a.card-link").map { Rack::Utils.parse_nested_query(URI(it["href"]).query).dig("grid", "seen") }
    assert_equal [ "1970-01-01T00:00:00.000000Z" ] * 2, seen
  end

  test "the grid's pages: sixty cards each, the rest on the last, past it the empty line" do
    season = publish_sets_draft
    cards = season_cards(season)

    get library_cards_path(locale: :en, page: 2)
    assert_equal cards[60, 60].map { title(it) }, slots.map(&:second)
    assert_select ".collection-pages a[rel=prev][href='/en/library/cards?page=1']"

    get library_cards_path(locale: :en, page: 3)
    assert_equal 30, slots.size
    assert_select ".collection-pages a[rel=next]", false

    get library_cards_path(locale: :en, page: 9)
    assert_response :success
    assert_empty slots
    assert_select ".collection-grid__empty", "No more cards here: the grid ends on an earlier page. Go back to the last page."
    assert_select ".collection-pages a[rel=prev][href='/en/library/cards?page=3']"

    [ "abc", "99999999999999999999" ].each do |page|
      get library_cards_path(locale: :en, page:)
      assert_response :success
    end
    get library_cards_path(locale: :en, page: "abc")
    assert_equal 60, slots.size
  end

  test "a visitor sees every slot missing, no NOUVEAU and the Steam sign-in image, without a holdings query" do
    season = publish_sets_draft
    hold(accounts_players(:player), season_cards(season).first, 1, gained_at: 1.minute.ago)

    assert_no_queries_match(/game_holdings|game_player_states/) { get library_cards_path(locale: :en) }

    assert_response :success
    assert_equal season_cards(season).first(60).map { [ :missing, title(it), year(it) ] }, slots
    assert_select ".collection-slot__new, [data-controller=collection-seen]", false
    assert_select ".collection-status__value", "0 / 150"
    assert_select ".top-bar__end form.steam-sign-in input[name=origin][value='/en/library/cards']"
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
      assert_request_queries(1 + 9) { get library_cards_path(locale: :en) }
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

    get library_cards_path(locale: :fr)

    # Owned cards first, newest gained first, the one never gained last,
    # then the missing ones.
    assert_equal [ [ :owned, title(second, "fr"), "x1", "Nouveau" ], [ :owned, title(first, "fr"), "x2", "Nouveau" ],
      [ :owned, title(fourth, "fr"), "x1", nil ], [ :owned, title(third, "fr"), "x1", nil ] ], slots.first(4)
    assert_equal :missing, slots[4].first
    assert_select "div[hidden][data-controller=collection-seen][data-collection-seen-url-value='/fr/library/seen']" do |element|
      assert_equal latest.utc.iso8601(6), element.first["data-collection-seen-up-to-value"]
    end

    Game::MarkCollectionSeen.new.call(player:, up_to: latest)
    get library_cards_path(locale: :fr)

    assert_select ".collection-slot__new", false
    assert_select "[data-controller=collection-seen]", false
  end

  test "the page writes nothing: the watermark moves only by its POST" do
    season = publish_sets_draft
    player = accounts_players(:player)
    hold(player, season_cards(season).first, 1, gained_at: 1.minute.ago)
    sign_in(player)

    assert_no_changes -> { Game::PlayerState.find_by!(player_id: player.id).attributes } do
      get library_cards_path(locale: :en)
      get library_set_path(locale: :en, kind: "theme", key: "rpg")
    end
  end

  test "a new card hidden by the filters carries no post; shown first, it carries one" do
    season = publish_sets_draft
    player = accounts_players(:player)
    hold(player, season_cards(season).last, 1, gained_at: 1.minute.ago)
    sign_in(player)

    get library_cards_path(locale: :en, state: %w[missing])
    assert_select "[data-controller=collection-seen]", false

    get library_cards_path(locale: :en, state: %w[all], page: 2)
    assert_select ".collection-slot__new", false
    assert_select "[data-controller=collection-seen]", false

    # Newest gained first: on the first page, tagged, with its post.
    get library_cards_path(locale: :en, state: %w[all])
    assert_select ".collection-slot__new", "New"
    assert_select "[data-controller=collection-seen]"
  end

  [ nil, "", "nope", [ "ufo" ], "studio" ].each do |kind|
    test "a kind of #{kind.inspect} lists the themes" do
      publish_sets_draft

      get library_cards_path(locale: :en), params: { kind: }.compact

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

    get library_cards_path(locale: :fr, kind: "ufo")
    assert_select ".collection-kind[aria-current=true]", "OVNI"
    assert_equal [ [ "Toute la saison", "1/150" ], [ "Les OVNI", "1/15" ] ], set_rows
    assert_equal "Toute la saison", current_row
    assert_equal [ "/fr/library/cards?kind=ufo", "/fr/library/ufo/ufos" ], css_select(".collection-sets .set-row").map { it["href"] }
  end

  test "franchises and studios have their tabs and list their sets by name, in English and French" do
    publish_franchises_and_studios_draft

    get library_cards_path(locale: :en)
    assert_equal [ "Themes", "Franchises", "Studios", "UFOs" ], css_select(".collection-kinds a.collection-kind").map(&:text)

    get library_cards_path(locale: :en, kind: "franchise")
    assert_select ".collection-kind[aria-current=true]", "Franchises"
    assert_equal [ [ "Whole season", "0/24" ], [ "Tom Clancy", "0/3" ] ], set_rows
    assert_equal "/en/library/franchise/tom-clancy", css_select(".collection-sets .set-row").last["href"]

    get library_cards_path(locale: :fr, kind: "studio")
    assert_select ".collection-kind[aria-current=true]", "Studios"
    assert_equal [ [ "Toute la saison", "0/24" ], [ "CAPCOM", "0/3" ] ], set_rows
    assert_equal [ "Thèmes", "Franchises", "Studios", "OVNI" ], css_select(".collection-kinds a.collection-kind").map(&:text)
  end

  test "the hall of fame has its tab and lists its sets in their fixed order, by name, in English and French" do
    publish_hall_of_fame_draft

    get library_cards_path(locale: :en)
    assert_equal [ "Themes", "Hall of fame" ], css_select(".collection-kinds a.collection-kind").map(&:text)

    get library_cards_path(locale: :en, kind: "hall_of_fame")
    assert_select ".collection-kind[aria-current=true]", "Hall of fame"
    assert_equal [ [ "Whole season", "0/24" ], [ "The Untouchables", "0/2" ], [ "Hidden Gems", "0/1" ], [ "The Unloved", "0/2" ],
      [ "The Phenomena", "0/2" ] ], set_rows
    assert_equal "/en/library/hall_of_fame/mal-aimes", css_select(".collection-sets .set-row")[3]["href"]

    get library_cards_path(locale: :fr, kind: "hall_of_fame")
    assert_select ".collection-kind[aria-current=true]", "Panthéon"
    assert_equal [ "Toute la saison", "Les Intouchables", "Les Pépites", "Les Mal-aimés", "Les Phénomènes" ], set_rows.map(&:first)
  end

  test "a season without themes keeps its kinds' tabs, opening on the first, each kind in its order" do
    seed_published_sets([
      [ "studio", "valve", { "studio" => "Valve" } ], [ "franchise", "halo", { "franchise" => "Halo" } ],
      [ "franchise", "doom", { "franchise" => "Doom" } ]
    ])

    get library_cards_path(locale: :en)
    assert_equal [ [ "Franchises", "/en/library/cards?kind=franchise", "true" ], [ "Studios", "/en/library/cards?kind=studio", nil ] ],
      css_select(".collection-kinds a.collection-kind").map { [ it.text, it["href"], it["aria-current"] ] }
    assert_equal [ [ "Whole season", "0/0" ], [ "Doom", "0/0" ], [ "Halo", "0/0" ] ], set_rows

    get library_cards_path(locale: :en, kind: "studio")
    assert_equal [ "Whole season", "Valve" ], set_rows.map(&:first)
    assert_equal [ "Valve" ], css_select("[data-group=sets] .filter-chip__text").map(&:text)

    get library_cards_path(locale: :en, kind: "theme")
    assert_select ".collection-kind[aria-current=true]", "Franchises"
  end

  test "a season without sets says so" do
    seed_published_sets([])

    get library_cards_path(locale: :en)

    assert_response :success
    assert_select ".collection-kinds a", false
    assert_equal [ [ "Whole season", "0/0" ] ], set_rows
    assert_select ".collection-sets__empty", "No theme in this season."
    assert_select ".collection-sets .series-nav", false
    assert_select ".collection-grid__empty", "Nothing matches these filters."
    assert_select ".collection-pages", false
  end

  test "120 studios come fifty to a list page (shelf), kept by the rows' links; past the last the list says so" do
    seed_published_sets((1..120).map { |number| [ "studio", format("studio-%03d", number), { "studio" => format("Studio %03d", number) } ] })

    get library_cards_path(locale: :en)
    assert_equal 51, set_rows.size
    assert_equal "Studio 001", set_rows.second.first
    assert_select ".collection-sets .series-nav a[aria-current=page]", "1"
    assert_select ".collection-sets .series-nav a[href='/en/library/cards?shelf=2']", minimum: 1
    assert_select ".collection-sets .series-nav a[href]:not([data-turbo-prefetch=false])", false

    get library_cards_path(locale: :en, shelf: 3)
    assert_equal [ "Whole season", "Studio 101" ], set_rows.first(2).map(&:first)
    assert_equal 21, set_rows.size
    assert_equal "/en/library/cards?kind=studio&shelf=3", css_select(".collection-sets .set-row").first["href"]
    assert_equal "/en/library/studio/studio-101?shelf=3", css_select(".collection-sets .set-row")[1]["href"]

    get library_cards_path(locale: :en, shelf: 9)
    assert_response :success
    assert_equal 1, set_rows.size
    assert_select ".collection-sets__empty", "This list ends on an earlier page."
    assert_select ".collection-sets .series-nav a[href='/en/library/cards?shelf=3']", minimum: 1
  end

  test "the genre chips filter the grid, OR within the group; an unknown genre is ignored" do
    season = publish_sets_draft
    roguelike = main_theme_cards(season, "roguelike")
    rpg = main_theme_cards(season, "rpg")

    get library_cards_path(locale: :fr, kind: "ufo", shelf: 1, state: %w[all])
    assert_equal [ "Horreur", "Roguelike", "RPG" ], css_select("[data-group=genre] .filter-chip__text").map(&:text)
    assert_equal [ "genre[]" ], css_select("[data-group=genre] input").map { it["name"] }.uniq
    assert_equal [ "ufo" ], css_select("form.filters input[name=kind]").map { it["value"] }

    get library_cards_path(locale: :en, genre: [ "rpg" ], state: %w[all])
    assert_equal [ "RPG" ], css_select("[data-group=genre] .filter-chip__box[checked]").map { it.parent.text.strip }
    assert_equal season_cards(season).select { it.in?(rpg) }.map { title(it) }, slots.map(&:second)

    get library_cards_path(locale: :en, genre: [ "rpg", "roguelike" ], state: %w[all])
    assert_equal season_cards(season).select { it.in?(rpg + roguelike) }.first(60).map { title(it) }, slots.map(&:second)

    get library_cards_path(locale: :en, genre: [ "rpg" ], state: %w[all], page: 2)
    assert_empty slots
    assert_select ".collection-grid__empty", "No more cards here: the grid ends on an earlier page. Go back to the last page."

    [ "strategy", [ "strategy" ] ].each do |genre|
      get library_cards_path(locale: :en), params: { genre: }
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

    get library_cards_path(locale: :fr, state: %w[all])

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

    get library_cards_path(locale: :en)

    assert_response :success
    assert_select ".collection-none p.panel", "No season of cards is published yet."
    assert_select ".collection, .collection-status", false

    get library_cards_path(locale: :fr)

    assert_select ".collection-none p.panel", "Aucune saison de cartes n'est publiée pour l'instant."
  end

  test "with no season published the entry says so, with no set and no search" do
    catalog_seasons(:one).update_columns(status: "draft", published_at: nil)
    sign_in(accounts_players(:player))

    get library_path(locale: :en, q: "souls")

    assert_response :success
    assert_select ".collection-none p.panel", "No season of cards is published yet."
    assert_select ".set-entry, .set-row, .collection-status", false
  end

  test "no set or card-season id reaches the page" do
    season = publish_sets_draft
    player = accounts_players(:player)
    hold(player, season_cards(season).first, 2, gained_at: 1.minute.ago)
    sign_in(player)
    ids = Catalog::Set.where(season_id: season.id).ids + Catalog::CardSeason.where(season_id: season.id).ids

    get library_cards_path(locale: :en)

    assert_select ".collection [data-id]", false
    assert_equal %w[collection-sets-title collection-report-title collection-search collection-results], css_select(".collection [id]").map { it["id"] }
    html = css_select(".collection").sole.to_html
    ids.each do |id|
      assert_no_match(/\b#{id}\b/, html.gsub(/\d+\/\d+|\d+ (cards?|copies|copy|duplicates?) |out of \d+|\b(19|20)\d\d\b|x\d+|seed-\d+-\d+|data-card-art-(width|height)-value="\d+"|width="\d+"|height="\d+"|viewbox="[\d ]+"|\?(page|shelf)=\d+|\/seasons\/\d+|value="\d+"|max="\d+"|[Ss]eason \d+|#\d+|Page<\/span> \d+|<dd>\d+<\/dd>|[MmHhVvZz][\d.-]+/, ""))
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
    # copies per tier; the tab bar's trades waiting. No set per card: the
    # links carry the grid, which the detail reads itself.
    assert_request_queries(16) { get library_cards_path(locale: :en) }

    delete session_path(locale: :en)
    # The same without the lookup, the progress, the slots, the unique cards
    # and the copies per tier.
    assert_request_queries(9) { get library_cards_path(locale: :en) }
  end

  test "the collection opens on every slot, the owned cards first, newest gained first, FILTRES folded with no count" do
    season = publish_sets_draft
    player = accounts_players(:player)
    first, second, third = season_cards(season).first(3)
    hold(player, first, 1, gained_at: 3.hours.ago)
    hold(player, second, 2, gained_at: 1.hour.ago)
    hold(player, third, 1)
    sign_in(player)

    get library_cards_path(locale: :en)

    assert_equal [ second, first, third ].map { [ :owned, title(it), nil ] }, slots.first(3).map { [ it[0], it[1], nil ] }
    assert_equal [ :missing ] * 57, slots.drop(3).map(&:first)
    assert_select "form.filters[method=get][data-controller=collection-filters][data-turbo-frame=collection-results]"
    assert_select "details.filters__zone:not([open]) summary", /Filters/
    assert_select ".filters__count[hidden]"
    assert_select ".filters__clear[hidden]"
    assert_select "turbo-frame#collection-results[target=_top] .collection-grid"
    assert_select "input[type=search][name=q]#collection-search"
    assert_equal [ "All" ], css_select("[data-group=state] .filter-chip__box[checked]").map { it.parent.text.strip }
    assert_equal [ "Common", "Uncommon", "Rare", "Epic", "Legendary" ], css_select("[data-group=rarity] .filter-chip__text").map(&:text)
    assert_equal [ "Horror", "Pirates", "Roguelike", "RPG" ], css_select("[data-group=sets] .filter-chip__text").map(&:text)
  end

  test "a state chosen beside the default every slot narrows the grid to it, counted once" do
    season = publish_sets_draft
    player = accounts_players(:player)
    first, second = season_cards(season).first(2)
    hold(player, first, 1, gained_at: 1.hour.ago)
    hold(player, second, 1, gained_at: 1.minute.ago)
    sign_in(player)

    get library_cards_path(locale: :en, state: %w[all owned])

    assert_equal [ second, first ].map { title(it) }, slots.map(&:second)
    assert_equal [ "Owned" ], css_select("[data-group=state] .filter-chip__box[checked]").map { it.parent.text.strip }
    assert_select ".filters__count:not([hidden])", /1/
  end

  test "the missing state shows the empty slots naming the game; owned plus missing is every slot" do
    season = publish_sets_draft
    player = accounts_players(:player)
    cards = season_cards(season)
    hold(player, cards.first, 1)
    sign_in(player)

    get library_cards_path(locale: :en, state: %w[missing])
    assert_equal cards.drop(1).first(60).map { [ :missing, title(it), year(it) ] }, slots
    assert_select ".filters__count:not([hidden])", /1/
    assert_select "details.filters__zone[open]"
    assert_select ".filters__clear:not([hidden])[href=?]", "/en/library/cards"

    get library_cards_path(locale: :en, state: %w[owned missing])
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

    get library_cards_path(locale: :en, state: %w[new])
    assert_equal [ title(second) ], slots.map(&:second)

    get library_cards_path(locale: :en, state: %w[duplicates])
    assert_equal [ title(first), title(third) ], slots.map(&:second)

    get library_cards_path(locale: :en, state: %w[new duplicates])
    assert_equal [ second, first, third ].map { title(it) }, slots.map(&:second)

    get library_cards_path(locale: :en, state: %w[bogus])
    assert_equal [ second, first, third ].map { title(it) }, owned_slots.map(&:second)
    assert_equal 60, slots.size
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

    get library_cards_path(locale: :en, genre: %w[rpg])
    assert_equal rpg.first(6).map { title(it) }.sort, owned_slots.map(&:second).sort

    get library_cards_path(locale: :en, genre: %w[rpg roguelike])
    assert_equal sample.size, owned_slots.size

    rarity = Catalog::CardSeason.where(id: sample).pick(:rarity)
    both = Catalog::CardSeason.where(id: sample, rarity:).count
    get library_cards_path(locale: :en, genre: %w[rpg roguelike], rarity: [ rarity ])
    assert_equal both, owned_slots.size
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

    get library_cards_path(locale: :en, sets: %w[theme:horror theme:rpg])
    assert_equal 5, owned_slots.size
    assert_equal [ "Horror", "RPG" ], css_select("[data-group=sets] .filter-chip__box[checked]").map { it.parent.text.strip }

    get library_cards_path(locale: :en, sets: %w[theme:rpg])
    assert_equal 2, owned_slots.size
  end

  test "a search over title and publisher narrows the grid with the other filters; an empty result shows the empty-filter line" do
    season = publish_sets_draft
    player = accounts_players(:player)
    titled = Catalog::CardSeason.where(season_id: season.id).joins(card: :texts).where(catalog_card_texts: { locale: "en", title: "Seed 5" }).pick(:id)
    published = Catalog::CardSeason.where(season_id: season.id).joins(:card).where(catalog_cards: { publisher: "P" }).ids
    ([ titled ] + published).each { hold(player, it, 1) }
    sign_in(player)

    get library_cards_path(locale: :en, q: "seed 5")
    assert_equal "Seed 5", slots.first.second
    assert_select "input[name=q][value=?]", "seed 5"
    assert_select ".filters__clear:not([hidden])"

    get library_cards_path(locale: :en, q: "P", state: %w[all])
    assert_operator slots.size, :>=, 5

    get library_cards_path(locale: :en, q: "seed 5", state: %w[missing])
    assert slots.any?
    assert slots.all? { it.first == :missing && it.second.start_with?("Seed 5") && it.second != "Seed 5" }

    get library_cards_path(locale: :en, q: "zzzz")
    assert_empty slots
    assert_select ".collection-grid__empty", "Nothing matches these filters."
    assert_select ".collection-pages", false

    get library_cards_path(locale: :en, q: "%")
    assert_empty slots
  end

  test "a visitor, and a player owning nothing, open on every slot; owned shows none" do
    season = publish_sets_draft
    get library_cards_path(locale: :en)
    assert_equal 60, slots.size
    assert_equal [ "All" ], css_select("[data-group=state] .filter-chip__box[checked]").map { it.parent.text.strip }
    assert_select ".filters__count[hidden]"
    assert_select "[data-group=state][data-default=all]"
    assert_select "form.filters[role=search]"
    assert_select "turbo-frame#collection-results p[role=status]", "150 cards shown."

    # Asking "all" explicitly is the default of this viewer: no filter on.
    get library_cards_path(locale: :en, state: %w[all])
    assert_select ".filters__count[hidden]"
    assert_select ".filters__clear[hidden]"

    get library_cards_path(locale: :en, state: %w[owned])
    assert_empty slots
    assert_select "turbo-frame#collection-results p[role=status]", "No card shown."

    get library_cards_path(locale: :en, state: %w[missing])
    assert_equal 60, slots.size

    sign_in(accounts_players(:player))
    get library_cards_path(locale: :en)
    assert_equal season_cards(season).first(60).map { [ :missing, title(it), year(it) ] }, slots
  end

  test "the filters apply inside a set page and the list keeps its kind" do
    season = publish_sets_draft
    player = accounts_players(:player)
    members = set_members(season, "roguelike")
    hold(player, members[3], 1)
    sign_in(player)

    get library_set_path(locale: :en, kind: "theme", key: "roguelike", rarity: Catalog::Rarity::TIERS.values.map(&:to_s))
    assert_equal [ title(members[3]) ], owned_slots.map(&:second)
    assert_select ".filters__clear[href=?]", "/en/library/theme/roguelike"
  end

  # ---- The entry ----

  # The rows of an entry section ("in-progress", "discover", "results") as
  # [ name, kind, tier mark, "owned/total" ].
  def entry_rows(section)
    css_select("#set-entry-#{section}-title ~ .set-entry__list .set-row, #set-#{section}-title ~ .set-entry__list .set-row").map do |row|
      [ row.at_css(".set-row__name").text, row.at_css(".set-row__kind").text, row.at_css(".set-tier")&.text, row.at_css(".set-row__count").text ]
    end
  end

  def entry_row(name) = css_select(".set-entry .set-row").find { it.at_css(".set-row__name").text == name }

  def sentence(name) = entry_row(name).at_css(".visually-hidden").text

  # A season of `count` cards, reviewed more the later they come, so a set
  # of later cards is more popular; its card-season ids are taken in order.
  def entry_season(count = 300)
    @season, @cards = published_cards(count, review_counts: Array.new(count) { (it + 1) * 10 })
  end

  def take(count) = @cards.shift(count)

  def theme(key, size)
    members = take(size)
    insert_theme(members, key:, season: @season)
    members
  end

  def named(kind, name, size)
    members = take(size)
    insert_set(members, { complete: size }, kind:, key: name.parameterize, params: { kind => name }, season: @season)
    members
  end

  def count_queries(&request)
    ActiveRecord::Base.connection.clear_query_cache
    queries = 0
    counter = ->(*, payload) { queries += 1 unless payload[:name].in?([ "SCHEMA", "TRANSACTION" ]) || payload[:cached] }
    ActiveSupport::Notifications.subscribed(counter, "sql.active_record", &request)
    queries
  end

  test "the entry opens on the sets closest to their next tier or completion, each row read as one sentence" do
    entry_season
    player = accounts_players(:player)
    halo = named("franchise", "Halo", 3)
    roguelike = theme("roguelike", 62)
    supergiant = named("studio", "Supergiant", 5)
    metroidvania = theme("metroidvania", 77)
    theme("horror", 20)
    hold_all(player, halo.first(2) + roguelike.first(29) + supergiant.first(3) + metroidvania.first(40))
    sign_in(player)

    get library_path(locale: :en)

    assert_response :success
    assert_select "title", "Collection"
    assert_select "h1.visually-hidden", "Collection"
    assert_select ".top-bar__title", "Collection"
    assert_select ".top-bar__end .collection-status .collection-status__value", "74 / 300"
    assert_equal [ "In progress", "To discover", "Find a set" ], css_select(".set-entry h2").map(&:text)
    assert_equal [ [ "Halo", "Franchise", nil, "2/3" ], [ "Supergiant", "Studio", nil, "3/5" ], [ "Roguelike", "Theme", "Silver", "29/62" ],
      [ "Metroidvania", "Theme", "Gold", "40/77" ] ], entry_rows("in-progress")
    assert_equal "Halo, franchise, 2 cards out of 3", sentence("Halo")
    assert_equal "Roguelike, theme, 29 cards out of 62, silver tier, gold at 31", sentence("Roguelike")
    assert_equal "Metroidvania, theme, 40 cards out of 77, gold tier", sentence("Metroidvania")
    assert_equal [ "/en/library/franchise/halo", "/en/library/studio/supergiant", "/en/library/theme/roguelike", "/en/library/theme/metroidvania" ],
      css_select("#set-entry-in-progress-title ~ .set-entry__list a.set-row").map { it["href"] }
    row = entry_row("Roguelike")
    assert_equal [ "true" ] * 4, [ ".set-row__name", ".set-row__meta", ".set-row__count", ".set-row__track" ].map { row.at_css(it)["aria-hidden"] }
    assert_equal [ [ "bronze", true, 1 ], [ "silver", true, 2 ], [ "gold", false, 3 ] ], row.css(".set-row__tick").map { |tick|
      [ tick["class"][/--(\w+)/, 1], tick.classes.include?("is-reached"), tick.css(".set-notches i").size ]
    }
    assert_select "progress.set-row__bar[value='29'][max='62']"
    assert_empty entry_row("Halo").css(".set-row__tick")
    assert_equal [ [ "Horror", "Theme", nil, "0/20" ] ], entry_rows("discover")
    assert_select ".set-search__head a.button--link[href='/en/library/cards']", "All cards"
    assert_select "[style]", false
  end

  test "the entry costs the same queries with three sets started or forty" do
    entry_season(540)
    player = accounts_players(:player)
    sets = (1..45).map { theme("theme-#{it}", 12) }
    hold_all(player, sets.first(3).map(&:first))
    sign_in(player)

    three = count_queries { get library_path(locale: :en, q: "theme") }
    assert_equal 3, css_select("#set-entry-discover-title ~ .set-entry__list .set-row").count { it.at_css(".set-row__count").text == "1/12" }

    hold_all(player, sets[3, 37].flat_map { it.first(2) })
    forty = count_queries { get library_path(locale: :en, q: "theme") }
    assert_equal 10, entry_rows("in-progress").size
    assert_equal three, forty
    # Player lookup, season, unique cards and the season's count; the
    # standings, the popular fill and its figures, the sets named; the search's
    # sets and the figures of those not started; the tab bar's trades waiting.
    assert_equal 11, forty
  end

  test "a player who holds no card discovers four popular sets at 0, with no In progress heading; so does a visitor" do
    entry_season
    %w[horror pirates cosy roguelike rpg].each { theme(it, 20) }
    sign_in(accounts_players(:player))

    get library_path(locale: :fr)

    assert_select "#set-entry-in-progress-title", false
    assert_equal [ "À découvrir", "Chercher un set" ], css_select(".set-entry h2").map(&:text)
    assert_equal [ [ "RPG", "Thème", nil, "0/20" ], [ "Roguelike", "Thème", nil, "0/20" ], [ "Cosy", "Thème", nil, "0/20" ],
      [ "Pirates", "Thème", nil, "0/20" ] ], entry_rows("discover")
    assert_equal "RPG, thème, 0 carte sur 20, bronze à 2", sentence("RPG")

    delete session_path(locale: :fr)
    get library_path(locale: :en)
    assert_equal [ "RPG", "Roguelike", "Cosy", "Pirates" ], entry_rows("discover").map(&:first)
    assert_select "#set-entry-in-progress-title", false
  end

  test "the latest opening's set leads with its tier; a set touched once is to discover" do
    entry_season
    player = accounts_players(:player)
    closest = named("franchise", "Halo", 3)
    raised = theme("roguelike", 62)
    touched = theme("pirates", 18)
    latest = Time.utc(2026, 10, 17, 9)
    hold_all(player, closest.first(2))
    hold_all(player, raised.first(11), gained_at: latest - 1.day)
    hold_all(player, [ raised[11], touched.first ], gained_at: latest)
    set_id = Catalog::Set.find_by!(season_id: @season.id, key: "roguelike").id
    Game::SetTier.insert_all!([ { player_id: player.id, set_id:, tier: "bronze", reached_by: "trade", reached_at: latest, created_at: latest, updated_at: latest } ])
    sign_in(player)

    get library_path(locale: :fr)

    assert_equal [ [ "Roguelike", "Thème", "Bronze", "12/62" ], [ "Halo", "Franchise", nil, "2/3" ] ], entry_rows("in-progress")
    assert_equal "Roguelike, thème, 12 cartes sur 62, palier bronze, argent à 16", sentence("Roguelike")
    assert_equal [ "Pirates", "Thème", nil, "1/18" ], entry_rows("discover").first
  end

  test "a game held only in an earlier edition counts in the published season's set" do
    entry_season
    portal = Catalog::CardSeason.insert_all!([ { card_id: catalog_cards(:portal).id, season_id: @season.id, prestige_score: 0.9, rating: 95 } ],
      returning: :id).rows.flatten.sole
    insert_theme([ portal ] + take(19), key: "puzzle", season: @season)
    player = accounts_players(:player)
    hold(player, catalog_card_seasons(:portal_one).id, 1)
    sign_in(player)

    get library_path(locale: :en)

    assert_equal [ "Puzzle", "Theme", nil, "1/20" ], entry_rows("discover").first
  end

  test "the search finds a set by name, accents and case ignored; none says so; blank shows no results" do
    entry_season
    player = accounts_players(:player)
    souls = theme("souls_like", 10)
    %w[roguelike rpg horror].each { theme(it, 10) }
    complete = named("franchise", "Halo", 3)
    hold_all(player, souls.first(1))
    hold_all(player, complete, gained_at: 1.day.ago)
    sign_in(player)

    get library_path(locale: :fr, q: " souls ")

    assert_select "form.set-search__form[method=get][action='/fr/library'][role=search][aria-labelledby=set-search-title][data-controller=set-search]" do
      assert_select "input[type=search][name=q][value=souls][maxlength='100'][aria-labelledby=set-search-title]"
      assert_select "noscript input[type=submit][value=Chercher]"
      assert_select "p.set-search__status[role=status]", "1 set trouvé"
    end
    assert_select "#set-search-title", "Chercher un set"
    assert_select "turbo-frame#set-search-results[target=_top]" do
      assert_select "[data-set-search-summary][hidden]", "1 set trouvé"
      assert_select "h2#set-results-title", "Résultats"
    end
    assert_equal [ [ "Souls-like", "Thème", "Bronze", "1/10" ] ], entry_rows("results")
    assert_equal "/fr/library/theme/souls_like", css_select("#set-results-title ~ .set-entry__list a.set-row").sole["href"]

    get library_path(locale: :fr, q: "ZZZ")
    assert_select ".set-results__none", "Aucun set trouvé pour «\u202FZZZ\u202F»."
    assert_select ".set-search__status", "Aucun set trouvé"

    get library_path(locale: :fr, q: "HÂLO")
    assert_equal [ [ "Halo", "Franchise", "Complet", "3/3" ] ], entry_rows("results")
    assert_equal "Halo, franchise, 3 cartes sur 3, complet", sentence("Halo")
    assert_select "#set-entry-in-progress-title ~ .set-entry__list .set-row__name", { text: "Halo", count: 0 }

    get library_path(locale: :en, q: "r")
    # "Halo" is found by its kind, "Franchise".
    assert_equal [ "Roguelike", "RPG", "Halo", "Horror" ], entry_rows("results").map(&:first)
    assert_select ".set-search__status", "4 sets found"

    get library_path(locale: :fr, q: "theme")
    assert_equal 4, entry_rows("results").size

    get library_path(locale: :en, q: "  ")
    assert_select "#set-results-title", false
    assert_select ".set-search__status", ""
    assert_select "turbo-frame#set-search-results [data-set-search-summary]", ""
  end

  test "no set or card-season id reaches the entry, and its GET writes nothing" do
    entry_season
    player = accounts_players(:player)
    cards = theme("roguelike", 30) + theme("rpg", 30)
    hold_all(player, cards.first(5), gained_at: 1.minute.ago)
    sign_in(player)
    ids = Catalog::Set.where(season_id: @season.id).ids + Catalog::CardSeason.where(season_id: @season.id).ids

    assert_no_changes -> { [ Game::SetTier.count, Game::PlayerState.find_by!(player_id: player.id).attributes ] } do
      get library_path(locale: :en, q: "r")
    end

    html = css_select("main").sole.to_html
    assert_select "main [data-id]", false
    ids.each do |id|
      assert_no_match(/\b#{id}\b/, html.gsub(/\d+\/\d+|\d+ (cards?|sets?) |out of \d+|at \d+|value="\d+"|max="\d+"|maxlength="\d+"/, ""))
    end
  end
end
