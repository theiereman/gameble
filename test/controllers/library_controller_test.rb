require "test_helper"
require_relative "../support/catalog_seeds"
require_relative "../support/custom_sets"
require_relative "../support/game_sets"
require_relative "../support/library_requests"
require_relative "../support/steam_sign_in"

# The collection. Its entry: OBJECTIFS, the ways to all the cards and all the
# sets, then the six sets closest to their next tier across kinds, a frame
# loaded after the page, and the player's own sets. The All sets screen: every
# set behind a search and a filter row, its pages appended as it scrolls. Its grid of every card of the
# season: the top bar's unique cards, the RAPPORT, the filters (state,
# rarity, the set group that picks a kind then finds a set by name, genre)
# and the search, the grid of every card's face sixty to a page, a
# player's cards not held set apart, the NOUVEAU tag and its watermark post; for a player, a visitor and
# a banned player, who see no ownership data (no state filters, no RAPPORT, no
# unique cards); the queries of a request.
class LibraryControllerTest < ActionDispatch::IntegrationTest
  include CatalogSeeds
  include CustomSets
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

  # The set group's kinds as [ name, value, checked ], in order.
  def set_kinds
    css_select("[data-group=sets] input[type=radio][name=set_kind]").map { [ it.parent.at_css(".filter-chip__text").text, it["value"], it["checked"].present? ] }
  end

  def chosen_kind = set_kinds.select(&:last).sole.first

  # The set chips as [ name, value, checked ], in order.
  def set_chips
    css_select("turbo-frame#collection-set-options input[type=checkbox][name='sets[]']").map do |box|
      [ box.parent.at_css(".filter-chip__text").text, box["value"], box["checked"].present? ]
    end
  end

  def set_status = css_select("[data-group=sets] p.set-filter__status[role=status]").sole.text

  # The filter row's pastilles with chips on, as { name => count }.
  def pastille_counts
    css_select("a.filter-row__pastille").filter_map do |pastille|
      count = pastille.at_css(".filter-row__count")
      [ pastille.at_css(".filter-chip__text").children.first.text.strip, count.at_css("[data-pastille-number]").text.to_i ] unless count.key?("hidden")
    end.to_h
  end

  # The grid's slots: [ :owned, title, "xn", "New" | nil ], [ :not_owned,
  # title, year ] (a player's card not held) or [ :plain, title, year ] (a
  # visitor's).
  def slots(selector = ".collection-grid > li.collection-slot")
    css_select(selector).map do |slot|
      card = slot.at_css(".card")
      title = card.at_css(".card__title").text
      if slot.at_css(".collection-slot__copies")
        [ :owned, title, slot.at_css(".collection-slot__copies").text, slot.at_css(".collection-slot__new")&.text ]
      else
        [ card.classes.include?("card--not-owned") ? :not_owned : :plain, title, card.at_css(".card__year").text.to_i ]
      end
    end
  end

  STREAM = { "Accept" => "text/vnd.turbo-stream.html" }.freeze

  # The slots a stream answer appends to the grid, read as `slots`.
  def appended_slots = slots("turbo-stream[action=append][target=collection-slots] template > li.collection-slot")

  def stream_status = css_select("turbo-stream[action=update][target=collection-results-status] template").sole.text

  def stream_pages = "turbo-stream[action=replace][target=collection-pages] template > nav#collection-pages[data-next-page-target=pages]"

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
    sign_in(player)

    get library_cards_path(locale: :en, state: %w[all])

    assert_response :success
    assert_select "title", "All cards · Gameble"
    assert_select ".top-bar__start > a.button--secondary[href='/en']", "Bridge"
    assert_select ".top-bar__title", "Collection"
    assert_select ".top-bar__end button.collection-status[type=button][popovertarget=rarity-legend]" do
      assert_select ".collection-status__label[aria-hidden=true]", "Unique cards:"
      assert_select ".collection-status__value[aria-hidden=true]", "3 / 150"
      assert_select ".visually-hidden", "3 unique cards out of 150"
      assert_select "progress.collection-status__bar[value='3'][max='150'][aria-hidden=true]"
    end
    assert_select ".top-bar__end > .collection-status + #rarity-legend[popover]"
    assert_equal [ "3 / 150", "3 / 155" ], css_select("#rarity-legend tfoot td > [aria-hidden=true]").map { it.text.squish }
    assert_equal [ "Rarity", "This season", "All seasons", "Copies" ], css_select("#rarity-legend thead th").map { it.text.strip }
    assert_select "#rarity-legend tfoot td.rarity-legend__copies", "5"
    assert_equal "/en/library/cards?rarity%5B%5D=epic", css_select("#rarity-legend a.rarity-legend__link")[3]["href"]
    assert_select ".top-bar .rarity-counter, .top-bar .packs-chip", false
    assert_select ".top-bar .player-chip"
    assert_select "h1.visually-hidden", "All cards"
    assert_select ".set-row, .collection-sets, .collection-kind", false
    assert_select ".collection__aside > .report--panel"

    games = Catalog::CardSeason.where(id: [ first, second, third ]).pluck(:rarity).tally
    tiers = Catalog::Rarity::TIERS.values.to_h { [ I18n.t("catalog.rarity.#{it}", locale: :en), games.fetch(it.to_s, 0).to_s ] }
    assert_equal({ "Total cards" => "5", "Duplicates" => "2" }.merge(tiers), report)
    assert_select ".report--fold summary .report__line", "5 cards · 2 duplicates"
    assert_select ".report--fold .report__row dt", "Unique cards"

    assert_equal [ "Owned", "All", "Missing", "New", "Duplicates" ], css_select("[data-group=state] .filter-chip__text").map(&:text)
    assert_equal [ "All" ], css_select("[data-group=state] .filter-chip__box[checked]").map { it.parent.at_css(".filter-chip__text").text }
    expected = cards.first(60).map do |id|
      case id
      when first, third then [ :owned, title(id), "x1", nil ]
      when second then [ :owned, title(id), "x3", nil ]
      else [ :not_owned, title(id), year(id) ]
      end
    end
    assert_equal expected, slots
    not_owned = 60 - expected.count { it.first == :owned }
    assert_select "ol.collection-grid.collection-grid--fill", 1
    assert_select ".collection-grid .card.card--grid", 60
    assert_select ".collection-grid .card.card--m", false
    assert_select ".collection-slot__copies[aria-hidden=true] + .visually-hidden", "3 copies"
    assert_select ".collection-grid .card.card--not-owned > .card__lock > svg.pixel-icon[aria-hidden=true]", not_owned
    assert_select ".collection-grid .card.card--not-owned[data-controller], .collection-grid .card--not-owned .card__effects", false
    assert_select ".collection-grid .card:not(.card--not-owned)[data-controller=tilt]", 60 - not_owned
    # Every face leads to its card's detail in this season,
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

  test "the grid stands alone in the frame the filters reload, each slot a plain link to its card's own page" do
    publish_sets_draft
    sign_in(accounts_players(:player))

    get library_cards_path(locale: :en)

    assert_response :success
    assert_select "turbo-frame#collection-results[target=_top] > ol.collection-grid"
    assert_select "turbo-frame#card-detail", false
    assert_select "[data-controller~=collection-detail]", false
    assert_select ".collection[data-controller], .collection[data-action]", false
    assert_select "a.card-link[aria-current]", false
    links = css_select(".collection-grid > li > a.card-link")
    assert_not_empty links
    assert links.all? { it["href"].start_with?("/en/cards/") }
    assert links.none? { it["data-turbo-frame"] }
    assert_select "[style]", false
  end

  test "a held card's link and a not-owned one's carry the grid's filters and search, the not-owned one named so" do
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
    missing_view = Catalog::CardViews.call([ missing ], locale: :en).fetch(missing)
    missing_label = "#{missing_view.title}, #{missing_view.year}, #{I18n.t("catalog.rarity.#{missing_view.rarity}", locale: :en)}, " \
      "season #{season.number}, not owned"
    assert_select ".collection-grid a.card-link[href=?][aria-label=?] .card.card--not-owned", href.(missing, context), missing_label

    # Every slot by default, the held card first: only the search, always there.
    get library_cards_path(locale: :en)
    assert_equal [ href.(held, { q: "" }), href.(missing, { q: "" }) ], css_select(".collection-grid a.card-link").first(2).map { it["href"] }
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

    # The seventeen of a player's grid, the state asked sparing the count
    # read again from the query cache and adding the watermark.
    assert_request_queries(22) { get library_cards_path(locale: :en, state: %w[new duplicates]) }
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

  test "a visitor's next page answers as a Turbo Stream: its slots appended in grid order, the status line, that page's links" do
    season = publish_sets_draft
    cards = season_cards(season)

    get library_cards_path(locale: :en, page: 2), headers: STREAM

    assert_response :success
    assert_equal Mime[:turbo_stream], response.media_type
    assert_includes response.headers["Vary"].to_s.split(/,\s*/), "Accept"
    assert_equal cards[60, 60].map { [ :plain, title(it), year(it) ] }, appended_slots
    assert_equal "Cards 61 to 120 of 150 shown.", stream_status
    assert_select "#{stream_pages} a[rel=next][href='/en/library/cards?page=3']"
    assert_select "#{stream_pages} [aria-current=page]", /2/
    assert_equal %w[append update replace], css_select("turbo-stream").map { it["action"] }
    assert_select "turbo-stream [data-controller=collection-seen], turbo-stream .report--panel, turbo-stream form", false

    get library_cards_path(locale: :fr, page: 3), headers: STREAM

    assert_equal 30, appended_slots.size
    assert_equal "Cartes 121 à 150 sur 150 affichées.", stream_status
    assert_select "#{stream_pages} a[rel=prev][href='/fr/library/cards?page=2']"
    assert_select "#{stream_pages} a[rel=next]", false
  end

  test "a player's next page as a stream is the filtered grid's next page, in order, its links keeping the search and filters" do
    publish_sets_draft
    sign_in(accounts_players(:player))
    filters = { state: %w[missing], genre: %w[roguelike], q: "seed" }

    get library_cards_path(locale: :en, state: %w[missing], page: 2)
    expected = slots
    get library_cards_path(locale: :en, state: %w[missing], page: 2), headers: STREAM

    assert_equal 60, appended_slots.size
    assert_equal expected, appended_slots
    assert_select "#{stream_pages} a[rel=next][href='/en/library/cards?page=3&state%5B%5D=missing']"

    get library_cards_path(locale: :en, **filters, page: 2)
    expected = slots
    get library_cards_path(locale: :en, **filters, page: 2), headers: STREAM

    assert_equal 23, appended_slots.size
    assert_equal expected, appended_slots
    assert appended_slots.all? { it.first == :not_owned }
    assert_equal "Cards 61 to 83 of 83 shown.", stream_status
    assert_select "#{stream_pages} a[rel=prev][href='/en/library/cards?genre%5B%5D=roguelike&page=1&q=seed&state%5B%5D=missing']"
    assert_select "#{stream_pages} a[rel=next]", false
  end

  test "a next page showing new cards appends the watermark post of the latest gain it shows" do
    season = publish_sets_draft
    player = accounts_players(:player)
    held = season_cards(season).first(61)
    held.each_with_index { |id, index| hold(player, id, 1, gained_at: (index + 1).minutes.ago) }
    sign_in(player)

    get library_cards_path(locale: :en, page: 2), headers: STREAM

    oldest = Game::Holding.find_by!(player_id: player.id, card_season_id: held.last).last_gained_at
    assert_equal [ :owned, title(held.last), "x1", "New" ], appended_slots.first
    assert_select "turbo-stream[action=append][target=collection-results] template > [data-controller=collection-seen][data-collection-seen-up-to-value=?]",
      oldest.utc.iso8601(6)
  end

  test "a stream past the last page appends nothing and replaces the links with the way back" do
    publish_sets_draft

    get library_cards_path(locale: :en, page: 9), headers: STREAM

    assert_response :success
    assert_select "turbo-stream[action=append]", false
    assert_equal "No more cards shown.", stream_status
    assert_select "#{stream_pages} a[rel=prev][href='/en/library/cards?page=3']"

    get library_cards_path(locale: :fr, page: 9), headers: STREAM
    assert_equal "Plus aucune carte affichée.", stream_status
  end

  test "a visitor sees every card's plain face, no NOUVEAU, no ownership data and the Steam sign-in image, without a holdings query" do
    season = publish_sets_draft
    hold(accounts_players(:player), season_cards(season).first, 1, gained_at: 1.minute.ago)

    assert_no_queries_match(/game_holdings|game_player_states/) { get library_cards_path(locale: :en) }

    assert_response :success
    assert_equal season_cards(season).first(60).map { [ :plain, title(it), year(it) ] }, slots
    assert_select ".collection-grid .card--not-owned, .collection-grid .card__lock", false
    assert_select ".collection-grid .card[data-controller=tilt]", 60
    labels = css_select(".collection-grid a.card-link").map { it["aria-label"] }
    assert_equal 60, labels.size
    assert labels.none? { it.nil? || it.end_with?("not owned") }
    assert_select ".collection-slot__new, [data-controller=collection-seen]", false
    assert_select ".collection-status, .top-bar--status", false
    assert_select ".top-bar__end a[href=?]", "/en/sign-in?origin=%2Fen%2Flibrary%2Fcards"
    assert_select ".report, .collection__aside, #collection-report-title", false
    assert_select ".collection.collection--visitor > .collection__main"
    assert_select "[data-group=state], input[name='state[]']", false
    assert_select "input[type=search][name=q]#collection-search"
    assert_select "[data-group=rarity]"
    assert_select "[data-group=genre]"
    assert_equal [ "Horror", "Pirates", "Roguelike", "RPG" ], set_chips.map(&:first)
    assert_select "[style]", false
  end

  test "a player banned since signing in sees the collection as a visitor, with no ownership query" do
    season = publish_sets_draft
    player = accounts_players(:player)
    hold(player, season_cards(season).first, 1, gained_at: 1.minute.ago)
    sign_in(player)
    player.update_columns(banned_at: Time.current)

    assert_no_queries_match(/game_holdings|game_player_states/) do
      # The visitor's nine (seven, the themes' names and the market's state), after the lookup that finds the ban.
      assert_request_queries(1 + 10) { get library_cards_path(locale: :en) }
    end

    assert_response :success
    assert_equal :plain, slots.first.first
    assert_select ".collection-grid .card--not-owned", false
    assert_select ".collection-slot__new", false
    assert_select "[data-group=state], .report, .collection__aside, .collection-status", false
    assert_select ".top-bar__end a[href^='/en/sign-in']"
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
    # then the ones not owned.
    assert_equal [ [ :owned, title(second, "fr"), "x1", "Nouveau" ], [ :owned, title(first, "fr"), "x2", "Nouveau" ],
      [ :owned, title(fourth, "fr"), "x1", nil ], [ :owned, title(third, "fr"), "x1", nil ] ], slots.first(4)
    assert_equal :not_owned, slots[4].first
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

  test "the set group picks a kind among those the season holds, in their order, then lists the kind's sets by name" do
    publish_sets_draft

    get library_cards_path(locale: :en)

    assert_select "form.filters fieldset.filters__group[data-group=sets]" do
      assert_select "legend.filters__legend", "Set"
      assert_select "fieldset.set-filter__kinds legend.visually-hidden", "Kind"
      assert_select "label.set-filter__label[for=collection-set-search]", "Find a set"
      assert_select "input[type=search][name=set_q]#collection-set-search[maxlength='100'][autocomplete=off]:not([placeholder])"
      assert_select "turbo-frame#collection-set-options:not([target]) [data-set-filter-summary][hidden]", "4 sets found"
    end
    assert_equal [ [ "Theme", "theme", true ], [ "UFO", "ufo", false ] ], set_kinds
    assert_equal [ [ "Horror", "theme:horror", false ], [ "Pirates", "theme:pirates", false ], [ "Roguelike", "theme:roguelike", false ],
      [ "RPG", "theme:rpg", false ] ], set_chips
    assert_equal "4 sets found", set_status

    get library_cards_path(locale: :fr, set_kind: "ufo")
    assert_equal "OVNI", chosen_kind
    assert_equal [ [ "Les OVNI", "ufo:ufos", false ] ], set_chips
    assert_equal "1 set trouvé", set_status
    assert_select "label.set-filter__label", "Chercher un set"
    assert_select "fieldset.set-filter__kinds legend", "Sorte"
  end

  [ nil, "", "nope", [ "ufo" ], "studio" ].each do |set_kind|
    test "a set kind of #{set_kind.inspect} picks the first kind held" do
      publish_sets_draft

      get library_cards_path(locale: :en), params: { set_kind: }.compact

      assert_response :success
      assert_equal "Theme", chosen_kind
      assert_equal 4, set_chips.size
    end
  end

  test "franchises, studios and the hall of fame have their kinds, their sets by name, in English and French" do
    publish_franchises_and_studios_draft

    get library_cards_path(locale: :en)
    assert_equal [ "Theme", "Franchise", "Studio", "UFO" ], set_kinds.map(&:first)

    get library_cards_path(locale: :en, set_kind: "franchise")
    assert_equal [ [ "Tom Clancy", "franchise:tom-clancy", false ] ], set_chips

    get library_cards_path(locale: :fr, set_kind: "studio")
    assert_equal [ "Thème", "Franchise", "Studio", "OVNI" ], set_kinds.map(&:first)
    assert_equal [ [ "CAPCOM", "studio:capcom", false ] ], set_chips

    publish_hall_of_fame_draft

    get library_cards_path(locale: :en, set_kind: "hall_of_fame")
    assert_equal [ "Theme", "Hall of fame" ], set_kinds.map(&:first)
    assert_equal [ "Hidden Gems", "The Phenomena", "The Unloved", "The Untouchables" ], set_chips.map(&:first)

    get library_cards_path(locale: :fr, set_kind: "hall_of_fame")
    assert_equal "Palmarès", chosen_kind
    assert_equal [ "Les Intouchables", "Les Mal-aimés", "Les Pépites", "Les Phénomènes" ], set_chips.map(&:first)
  end

  test "a season without themes opens its set group on its first kind; a kind it lacks picks the first" do
    seed_published_sets([
      [ "studio", "valve", { "studio" => "Valve" } ], [ "franchise", "halo", { "franchise" => "Halo" } ],
      [ "franchise", "doom", { "franchise" => "Doom" } ]
    ])

    get library_cards_path(locale: :en)
    assert_equal [ [ "Franchise", "franchise", true ], [ "Studio", "studio", false ] ], set_kinds
    assert_equal [ "Doom", "Halo" ], set_chips.map(&:first)

    get library_cards_path(locale: :en, set_kind: "studio")
    assert_equal [ "Valve" ], set_chips.map(&:first)

    get library_cards_path(locale: :en, set_kind: "theme")
    assert_equal "Franchise", chosen_kind
  end

  test "a season without sets has no set group" do
    seed_published_sets([])

    get library_cards_path(locale: :en)

    assert_response :success
    assert_select "[data-group=sets], input[name=set_kind], input[name=set_q], turbo-frame#collection-set-options", false
    assert_select ".collection-grid__empty", "Nothing matches these filters."
    assert_select ".collection-pages", false
  end

  test "a set is found by typing its name in the kind chosen, names starting with it first, without filtering the grid" do
    season = publish_sets_draft
    [ "Dark Souls", "Darksiders", "The Dark Pictures", "Halo" ].each do |name|
      insert_set([], {}, kind: "franchise", key: name.parameterize, params: { "franchise" => name }, season:)
    end

    get library_cards_path(locale: :en, set_kind: "franchise", set_q: "dark")

    assert_equal "Franchise", chosen_kind
    assert_select "input[name=set_q][value=dark]"
    assert_equal [ [ "Dark Souls", "franchise:dark-souls", false ], [ "Darksiders", "franchise:darksiders", false ],
      [ "The Dark Pictures", "franchise:the-dark-pictures", false ] ], set_chips
    assert_equal "3 sets found", set_status
    assert_equal 60, slots.size
    assert_select "turbo-frame#collection-results p[role=status]", "150 cards shown."
    assert_empty pastille_counts
    assert_select ".filters__clear[hidden]"
    assert_select ".collection-grid a.card-link[href*=set_]", false

    get library_cards_path(locale: :fr, set_kind: "theme", set_q: "ROGUÉ")
    assert_equal [ [ "Roguelike", "theme:roguelike", false ] ], set_chips

    get library_cards_path(locale: :en, set_kind: "studio", set_q: "zzz")
    assert_empty set_chips
    assert_equal "No set found for “zzz”.", set_status
    assert_select "[data-set-filter-summary]", "No set found for “zzz”."
    assert_equal 60, slots.size

    get library_cards_path(locale: :en, set_kind: "theme", set_q: "a" * 120)
    assert_select "input[name=set_q][value=?]", "a" * 100
  end

  test "the sets chosen are listed first and checked, whatever the kind and text; only they count as filters" do
    season = publish_sets_draft
    insert_set([], {}, kind: "franchise", key: "dark-souls", params: { "franchise" => "Dark Souls" }, season:)
    insert_set([], {}, kind: "franchise", key: "halo", params: { "franchise" => "Halo" }, season:)

    get library_cards_path(locale: :en, sets: %w[theme:roguelike], set_kind: "franchise", set_q: "dark")

    assert_equal [ [ "Roguelike", "theme:roguelike", true ], [ "Dark Souls", "franchise:dark-souls", false ] ], set_chips
    assert_equal({ "More" => 1 }, pastille_counts)
    assert_select ".filters__clear:not([hidden])[href=?]", "/en/library/cards"
    hrefs = css_select(".collection-grid a.card-link").map { Rack::Utils.parse_nested_query(URI(it["href"]).query).fetch("grid") }
    assert_equal [ { "sets" => [ "theme:roguelike" ], "q" => "" } ], hrefs.uniq
    assert_equal set_members(season, "roguelike").size, css_select("turbo-frame#collection-results p[role=status]").sole.text.to_i

    # A chosen set of the kind shown is listed once, first, and counts as found.
    get library_cards_path(locale: :en, sets: %w[theme:rpg], set_kind: "theme")
    assert_equal [ [ "RPG", "theme:rpg", true ], [ "Horror", "theme:horror", false ], [ "Pirates", "theme:pirates", false ],
      [ "Roguelike", "theme:roguelike", false ] ], set_chips
    assert_equal "4 sets found", set_status
  end

  test "a kind of two hundred sets offers twelve, at the same queries as a kind of three" do
    seed_published_sets((1..3).map { |number| [ "studio", format("studio-%03d", number), { "studio" => format("Studio %03d", number) } ] })

    three = count_queries { get library_cards_path(locale: :en) }
    assert_equal 3, set_chips.size

    seed_published_sets((1..200).map { |number| [ "studio", format("studio-%03d", number), { "studio" => format("Studio %03d", number) } ] })
    two_hundred = count_queries { get library_cards_path(locale: :en) }
    assert_equal (1..12).map { format("Studio %03d", it) }, set_chips.map(&:first)
    assert_equal "200 sets found", set_status
    assert_equal three, two_hundred
  end

  test "rarity and genre, or rarity and a set, narrow the grid together" do
    season = publish_sets_draft
    rare_rpg = Catalog::CardSeason.where(season_id: season.id, main_theme: "rpg", rarity: "rare").ids
    epic_roguelike = Catalog::CardSeason.where(id: set_members(season, "roguelike"), rarity: "epic").ids
    assert rare_rpg.any? && epic_roguelike.any?

    get library_cards_path(locale: :en, genre: %w[rpg], rarity: %w[rare])
    assert_equal rare_rpg.size, slots.size
    assert_select "turbo-frame#collection-results p[role=status]", "#{rare_rpg.size} cards shown."

    get library_cards_path(locale: :en, sets: %w[theme:roguelike], rarity: %w[epic])
    assert_equal epic_roguelike.map { title(it) }.sort, slots.map(&:second).sort
    assert_equal [ "Roguelike", "theme:roguelike", true ], set_chips.first
  end

  test "the genre chips filter the grid, OR within the group; an unknown genre is ignored" do
    season = publish_sets_draft
    roguelike = main_theme_cards(season, "roguelike")
    rpg = main_theme_cards(season, "rpg")

    get library_cards_path(locale: :fr, state: %w[all])
    assert_equal [ "Horreur", "Roguelike", "RPG" ], css_select("[data-group=genre] .filter-chip__text").map(&:text)
    assert_equal [ "genre[]" ], css_select("[data-group=genre] input").map { it["name"] }.uniq

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
      assert_empty pastille_counts
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

    assert_select ".collection-status__label", "Cartes uniques\u202F:"
    assert_select ".collection-status .visually-hidden", "1 carte unique sur 150"
    assert_select "#rarity-legend .shell-popover__title", "Raretés"
    assert_select "#rarity-legend a.rarity-legend__link[href=?] .rarity-legend__name", "/fr/library/cards?rarity%5B%5D=epic", "Épique"
    assert_select "#rarity-legend tfoot th", "Total"
    assert_select ".report--panel .report__title", "Rapport"
    assert_select ".report--fold .report__line", "1 carte · 0 doublon"
    assert_equal [ "Cartes totales", "Doublons" ], css_select(".report--panel .report__row dt").first(2).map { it.text.strip }
    assert_select ".collection-slot__new", "Nouveau"
    assert_select ".collection-slot__copies + .visually-hidden", "1 exemplaire"
    not_owned = Catalog::CardViews.call([ season_cards(season).second ], locale: :fr).fetch(season_cards(season).second)
    label = "#{not_owned.title}, #{not_owned.year}, #{I18n.t("catalog.rarity.#{not_owned.rarity}", locale: :fr)}, " \
      "saison #{season.number}, non possédée"
    assert_select ".collection-grid a.card-link[aria-label=?] .card--not-owned", label
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

    get library_cards_path(locale: :en, page: 2), headers: STREAM
    assert_response :success
    assert_select "turbo-stream", false
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
    assert_equal %w[collection-report-title collection-search filters-rarity filters-rarity-title filters-state filters-state-title
      filters-more filters-more-title collection-set-search collection-set-options collection-results collection-results-status collection-slots collection-pages],
      css_select(".collection [id]").map { it["id"] }
    html = css_select(".collection").sole.to_html
    ids.each do |id|
      assert_no_match(/\b#{id}\b/, html.gsub(/\d+\/\d+|\d+ (cards?|copies|copy|duplicates?) |out of \d+|\b(19|20)\d\d\b|x\d+|seed-\d+-\d+|data-card-art-(width|height)-value="\d+"|width="\d+"|height="\d+"|viewbox="[\d ]+"|\?(page|shelf)=\d+|\/seasons\/\d+|value="\d+"|max="\d+"|[Ss]eason \d+|#\d+|Page<\/span> \d+|<dd>\d+<\/dd>|[MmHhVvZz][\d.-]+/, ""))
    end
  end

  test "a player's request costs seventeen queries, a visitor's eight" do
    season = publish_sets_draft
    player = accounts_players(:player)
    hold(player, season_cards(season).first, 1, gained_at: 1.minute.ago)
    sign_in(player)

    # Player lookup, published season; the grid: genres, count of the
    # player's tiles, page, card views, the player's editions of the games
    # shown; the figures: the season's cards, games per rarity, copies per
    # tier; the rarity legend; the set group: the kinds the
    # season holds, the sets of the kind shown; the tab bar's trades and
    # invitations waiting; the themes' names; the player's goals. No set per
    # card: the links carry the grid, which the detail reads itself.
    assert_request_queries(21) { get library_cards_path(locale: :en) }

    delete session_path(locale: :en)
    # The same without the lookup, the player's editions, the figures, the
    # rarity legend and the trades and invitations waiting; the grid's count is the whole
    # season's, and the market's state.
    assert_request_queries(10) { get library_cards_path(locale: :en) }
  end

  test "the collection opens on every slot, the owned cards first, newest gained first, the filter row with no count" do
    season = publish_sets_draft
    player = accounts_players(:player)
    first, second, third = season_cards(season).first(3)
    hold(player, first, 1, gained_at: 3.hours.ago)
    hold(player, second, 2, gained_at: 1.hour.ago)
    hold(player, third, 1)
    sign_in(player)

    get library_cards_path(locale: :en)

    assert_equal [ second, first, third ].map { [ :owned, title(it), nil ] }, slots.first(3).map { [ it[0], it[1], nil ] }
    assert_equal [ :not_owned ] * 57, slots.drop(3).map(&:first)
    assert_select "form.filters[method=get][data-controller=collection-filters][data-turbo-frame=collection-results]"
    assert_select "form.filters > .filters__search + ul.filter-row[aria-label=Filters]"
    assert_empty pastille_counts
    assert_select ".filters__clear[hidden]"
    assert_select "turbo-frame#collection-results[target=_top] .collection-grid"
    assert_select "input[type=search][name=q]#collection-search"
    assert_equal [ "All" ], css_select("[data-group=state] .filter-chip__box[checked]").map { it.parent.text.strip }
    assert_equal [ "Common", "Uncommon", "Rare", "Epic", "Legendary" ], css_select("[data-group=rarity] .filter-chip__text").map(&:text)
    assert_equal [ "Horror", "Pirates", "Roguelike", "RPG" ], set_chips.map(&:first)
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
    assert_equal({ "State" => 1 }, pastille_counts)
  end

  test "the missing state shows the faces not owned; owned plus missing is every slot" do
    season = publish_sets_draft
    player = accounts_players(:player)
    cards = season_cards(season)
    hold(player, cards.first, 1)
    sign_in(player)

    get library_cards_path(locale: :en, state: %w[missing])
    assert_equal cards.drop(1).first(60).map { [ :not_owned, title(it), year(it) ] }, slots
    assert_equal({ "State" => 1 }, pastille_counts)
    assert_select ".filters__clear:not([hidden])[href=?]", "/en/library/cards"

    get library_cards_path(locale: :en, state: %w[owned missing])
    assert_equal :owned, slots.first.first
    assert_equal 60, slots.size
    assert_equal({ "State" => 2 }, pastille_counts)
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
    assert_equal({ "Rarity" => 1, "More" => 2 }, pastille_counts)
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
    assert_equal [ [ "Horror", "theme:horror", true ], [ "RPG", "theme:rpg", true ] ], set_chips.first(2)

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
    assert slots.all? { it.first == :not_owned && it.second.start_with?("Seed 5") && it.second != "Seed 5" }

    not_held = Catalog::CardSeason.where(season_id: season.id).joins(card: :texts)
      .where(catalog_card_texts: { locale: "en", title: "Seed 50" }).pick(:id)
    get library_cards_path(locale: :en, q: "seed 50")
    assert_equal [ [ :not_owned, "Seed 50", year(not_held) ] ], slots

    get library_cards_path(locale: :en, q: "zzzz")
    assert_empty slots
    assert_select ".collection-grid__empty", "Nothing matches these filters."
    assert_select ".collection-pages", false

    get library_cards_path(locale: :en, q: "%")
    assert_empty slots
  end

  test "a visitor opens on every slot and a state asked is ignored; a player owning nothing opens on every slot, owned showing none" do
    season = publish_sets_draft
    get library_cards_path(locale: :en)
    assert_equal 60, slots.size
    assert_select "[data-group=state]", false
    assert_empty pastille_counts
    assert_select "form.filters[role=search]"
    assert_select "turbo-frame#collection-results p[role=status]", "150 cards shown."

    %w[owned missing new duplicates].each do |state|
      get library_cards_path(locale: :en, state: [ state ])
      assert_equal season_cards(season).first(60).map { [ :plain, title(it), year(it) ] }, slots
      assert_select "turbo-frame#collection-results p[role=status]", "150 cards shown."
      assert_empty pastille_counts
      assert_select ".filters__clear[hidden]"
      assert css_select(".collection-grid a.card-link").none? { it["href"].include?("state") }
      assert css_select(".collection-pages a").none? { it["href"].include?("state") }
    end

    sign_in(accounts_players(:player))
    get library_cards_path(locale: :en)
    assert_equal season_cards(season).first(60).map { [ :not_owned, title(it), year(it) ] }, slots
    assert_equal [ "All" ], css_select("[data-group=state] .filter-chip__box[checked]").map { it.parent.text.strip }
    assert_select "[data-group=state][data-default=all]"

    # Asking "all" explicitly is the default of this viewer: no filter on.
    get library_cards_path(locale: :en, state: %w[all])
    assert_empty pastille_counts
    assert_select ".filters__clear[hidden]"

    get library_cards_path(locale: :en, state: %w[owned])
    assert_empty slots
    assert_select "turbo-frame#collection-results p[role=status]", "No card shown."
  end

  test "a visitor's search, rarity and set filters narrow the grid as a player's do; an empty result shows the empty-filter line" do
    season = publish_sets_draft
    rare = Catalog::CardSeason.where(season_id: season.id, rarity: "rare").ids
    epic_roguelike = Catalog::CardSeason.where(id: set_members(season, "roguelike"), rarity: "epic").ids
    assert rare.any? && epic_roguelike.any?

    get library_cards_path(locale: :en, q: "seed 50", state: %w[owned])
    assert_equal [ "Seed 50" ], slots.map(&:second)
    assert_equal :plain, slots.sole.first

    get library_cards_path(locale: :en, rarity: %w[rare])
    assert_equal season_cards(season).select { it.in?(rare) }.first(60).map { title(it) }, slots.map(&:second)
    assert_equal({ "Rarity" => 1 }, pastille_counts)

    get library_cards_path(locale: :en, sets: %w[theme:roguelike], rarity: %w[epic])
    assert_equal epic_roguelike.map { title(it) }.sort, slots.map(&:second).sort
    assert_equal [ "Roguelike", "theme:roguelike", true ], set_chips.first

    get library_cards_path(locale: :en, q: "zzzz")
    assert_empty slots
    assert_select ".collection-grid__empty", "Nothing matches these filters."
  end

  # ---- The entry ----

  # EN COURS, the frame the entry loads after the page.
  def get_in_progress(locale: :en) = get library_in_progress_path(locale:), headers: { "Turbo-Frame" => "set-entry-in-progress" }

  def tiles = css_select("turbo-frame#set-entry-in-progress #set-entry-in-progress-title ~ ul.set-tiles > li > a.set-tile")

  def see_all = css_select("turbo-frame#set-entry-in-progress section > a.button.button--link")

  # The tiles as [ name, kind, rank, "owned/total" ].
  def tile_rows
    tiles.map { [ it.at_css(".set-tile__name").text, it.at_css(".set-tile__kind").text, it.at_css(".set-chip--rank").text, it.at_css(".set-tile__count").text ] }
  end

  def tile(name) = tiles.find { it.at_css(".set-tile__name").text == name }

  def sentence(name) = tile(name).at_css("> .visually-hidden").text

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

  test "the entry leads with the goals and the ways to all the cards and all the sets, then loads EN COURS after the page: one list across kinds, closest to a tier first, each read as one sentence" do
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
    assert_equal [ "Goals", "My sets" ], css_select(".set-entry h2").map(&:text)
    assert_select ".set-entry form[role=search]", false
    assert_select "a.all-cards-tile[href='/en/library/cards']" do
      assert_select ".all-cards-tile__title", "All my cards"
      assert_select ".all-cards-tile__figures[aria-hidden=true] .all-cards-tile__count", "74/300"
      assert_select ".visually-hidden", "74 unique cards out of 300"
      assert_select "progress.all-cards-tile__bar[value='74'][max='300']"
      assert_select ".all-cards-tile__side[aria-hidden=true] .all-cards-tile__fan > .all-cards-tile__card > .card.card--s", 3
      assert_select ".all-cards-tile__open", "Open"
    end
    assert_select "a.all-cards-tile[href='/en/library/sets']" do
      assert_select ".all-cards-tile__title", "All sets"
      assert_select ".all-cards-tile__count", "5"
      assert_select ".all-cards-tile__unit", "sets"
      assert_select ".all-cards-tile__open", "Open"
    end
    assert_select ".set-entry > section#goals:first-child + a.all-cards-tile + a.all-cards-tile + " \
      "turbo-frame#set-entry-in-progress.set-entry__in-progress[src='/en/library/in-progress'][loading=lazy][target=_top] + section.custom-sets"
    assert_select "turbo-frame#set-entry-in-progress p.set-entry__loading", "Loading the sets in progress…"
    assert_select ".set-tile, .set-row, .set-entry__empty", false
    assert_select "[style]", false

    get_in_progress

    assert_response :success
    assert_select "turbo-frame#set-entry-in-progress[target=_top] > section.set-entry__section[aria-labelledby=set-entry-in-progress-title] > h2", "In progress"
    assert_equal [ [ "Halo", "Franchise", "No tier", "2/3" ], [ "Supergiant", "Studio", "No tier", "3/5" ], [ "Roguelike", "Theme", "Silver", "29/62" ],
      [ "Metroidvania", "Theme", "Gold", "40/77" ] ], tile_rows
    assert_equal "Halo, franchise, 2 cards out of 3", sentence("Halo")
    assert_equal "Roguelike, theme, 29 cards out of 62, silver tier, gold at 31", sentence("Roguelike")
    assert_equal "Metroidvania, theme, 40 cards out of 77, gold tier", sentence("Metroidvania")
    assert_equal [ "/en/library/franchise/halo", "/en/library/studio/supergiant", "/en/library/theme/roguelike", "/en/library/theme/metroidvania" ],
      tiles.map { it["href"] }
    tile = tile("Roguelike")
    assert_equal [ "true", "true" ], tile.css("> .set-tile__face").map { it["aria-hidden"] }
    assert_equal [ [ "bronze", true, 1, "0.1129" ], [ "silver", true, 2, "0.2581" ], [ "gold", false, 3, "0.5" ] ], tile.css(".set-row__tick").map { |tick|
      [ tick["class"][/--(\w+)/, 1], tick.classes.include?("is-reached"), tick.css(".set-notches i").size, tick["data-tier-at"] ]
    }
    assert_equal "tier-ticks", tile.at_css(".set-tile__track.set-tile__track--tiered")["data-controller"]
    assert_select "progress.set-row__bar[value='29'][max='62']"
    assert_empty tile("Halo").css(".set-row__tick")
    assert_nil tile("Horror")
    assert_select "a.set-tile a, a.set-tile button", false
    assert_select ".set-entry__empty", false
    assert_empty see_all
    assert_select "[style]", false
  end

  test "a tile's recto: its rank, its cards and what the next tier asks; its verso: the tier path, the game gained last and the way to the album" do
    entry_season
    player = accounts_players(:player)
    halo = named("franchise", "Halo", 3)
    roguelike = theme("roguelike", 62)
    Catalog::CardSeason.where(id: halo[2]).update_all(rarity: Catalog::Rarity::TIERS.key(:epic))
    Catalog::CardSeason.where(id: roguelike[20]).update_all(rarity: Catalog::Rarity::TIERS.key(:legendary))
    hold_all(player, halo.first(2), gained_at: 2.days.ago)
    hold_all(player, roguelike.first(29), gained_at: 3.hours.ago)
    sign_in(player)

    get_in_progress(locale: :fr)

    small = tile("Halo")
    assert_equal [ [ "card", nil ], [ "card", nil ], [ "missing", "rarity-tone--epic" ] ],
      small.css(".set-tile__cards > *").map { it.classes.include?("set-tile__missing") ? [ "missing", it.classes.grep(/rarity-tone/).sole ] : [ "card", nil ] }
    assert_equal [ title(halo[0], "fr").upcase, title(halo[1], "fr").upcase ], small.css(".set-tile__card .card.card--s .card__title").map(&:text).map(&:upcase)
    assert_equal "?", small.at_css(".set-tile__missing").text
    assert_select small, ".set-chip--rank.set-chip--none", "Aucun palier"
    assert_equal "Plus que 1 pour Complet", small.at_css(".set-tile__next").text.squish
    assert_select small, ".set-tile__next .set-chip.tier-tone--complete", "Complet"
    assert_equal [ [ "complete", "next", nil, "Complet", "3" ] ], path(small)
    assert_equal "Halo, franchise, 2 cartes sur 3", sentence("Halo")

    large = tile("Roguelike")
    assert_equal 3, large.css(".set-tile__card .card.card--s").size
    assert_equal title(roguelike[20], "fr"), large.at_css(".set-tile__card .card__title").text
    assert_equal "+26", large.at_css(".set-tile__more").text
    assert_select large, ".set-tile__missing", false
    assert_select large, ".set-chip--rank.tier-tone--silver", "Argent"
    assert_equal "Plus que 2 pour Or", large.at_css(".set-tile__next").text.squish
    assert_equal [ [ "bronze", "reached", nil, "Bronze", "7" ], [ "silver", "reached", "100", "Argent", "16" ], [ "gold", "next", "87", "Or", "31" ],
      [ "complete", "later", "0", "Complet", "62" ] ], path(large)
    assert_select large, ".set-tile__dot svg, .set-tile__dot:not(:empty)", false
    assert_equal "29/62", large.at_css(".set-tile__face--verso .set-tile__count").text

    assert_equal [ "Dernière obtenue", "il y a 2 jours" ], [ small.at_css(".set-tile__last-label").text, small.at_css(".set-tile__last-text").text.squish[/il y a .*\z/] ]
    assert_equal "il y a 3 h", large.at_css(".set-tile__last-text").text.squish[/il y a .*\z/]
    assert_select large, ".set-tile__last .set-tile__last-card .card.card--s", 1
    tiles.each { |tile| assert_select tile, ".set-tile__face--verso > span.button.button--primary.set-tile__cta:last-child", "Voir l'album" }
  end

  # The verso's tier path as [ tier, state, how much of the line to the node is lit, name, threshold ].
  def path(tile)
    tile.css(".set-tile__node").map do |node|
      [ node["class"][/tier-tone--(\w+)/, 1], node["class"][/set-tile__node--(\w+)/, 1], node.at_css("progress.set-tile__lit")&.[]("value"),
        node.at_css(".set-tile__node-name").text, node.at_css(".set-tile__node-required").text ]
    end
  end

  test "the set closest to its next tier, the first of a tie, wears the gold frame, one per list" do
    entry_season
    player = accounts_players(:player)
    far = theme("roguelike", 62)
    near = named("franchise", "Halo", 5)
    tied = named("studio", "Supergiant", 5)
    latest = Time.utc(2026, 10, 17, 9)
    hold_all(player, far.first(10), gained_at: latest - 1.day)
    hold_all(player, near.first(3) + tied.first(3), gained_at: latest - 1.day)
    hold_all(player, [ far[10] ], gained_at: latest)
    sign_in(player)

    get_in_progress

    assert_equal [ "Halo", "Supergiant", "Roguelike" ], tile_rows.map(&:first)
    assert_equal [ "Halo" ], tiles.select { it.classes.include?("set-tile--closest") }.map { it.at_css(".set-tile__name").text }
  end

  test "a complete set leaves EN COURS for the screen's complete state, the latest completed first; one just completed stays on the preview until it leaves" do
    entry_season
    player = accounts_players(:player)
    latest = Time.utc(2026, 10, 17, 9)
    halo = named("franchise", "Halo", 3)
    roguelike = theme("roguelike", 62)
    supergiant = named("studio", "Supergiant", 5)
    portal = named("franchise", "Portal", 2)
    horror = theme("horror", 20)
    fresh = named("franchise", "Fresh", 2)
    hold_all(player, halo.first(2) + roguelike.first(29) + supergiant.first(3) + fresh, gained_at: latest)
    Game::SetTier.insert_all!([ { player_id: player.id, set_id: Catalog::Set.find_by!(key: "fresh").id, tier: "complete", reached_by: "trade",
      reached_at: latest, created_at: latest, updated_at: latest } ])
    hold_all(player, portal, gained_at: latest - 3.days)
    hold_all(player, horror, gained_at: latest - 1.day)
    sign_in(player)

    get_in_progress

    assert_equal [ "In progress" ], css_select("turbo-frame#set-entry-in-progress > section.set-entry__section > h2").map(&:text)
    assert_select "#set-entry-completed-title", false
    assert_equal [ "Fresh", "Halo", "Supergiant", "Roguelike" ], tile_rows.map(&:first)
    assert_select "a.set-tile[href='/en/library/theme/horror'], a.set-tile[href='/en/library/franchise/portal']", false
    assert_equal [ "Halo" ], tiles.select { it.classes.include?("set-tile--closest") }.map { it.at_css(".set-tile__name").text }

    get library_sets_path(locale: :en, state: [ "complete" ])

    assert_equal [ [ "Fresh", "/en/library/franchise/fresh" ], [ "Horror", "/en/library/theme/horror" ], [ "Portal", "/en/library/franchise/portal" ] ],
      browser_tiles.map { [ it.at_css(".set-tile__name").text, it["href"] ] }
    assert browser_tiles.none? { it.classes.include?("set-tile--closest") }

    complete = browser_tiles[1]
    assert_select complete, ".set-chip--rank.tier-tone--complete", "Complete"
    assert_select complete, "progress.set-row__bar[value='20'][max='20']"
    assert_select complete, ".set-row__tick", false
    assert_equal "Every card collected", complete.at_css(".set-tile__next").text.squish
    assert_equal [ [ "bronze", "reached" ], [ "silver", "reached" ], [ "gold", "reached" ], [ "complete", "reached" ] ], path(complete).map { it.first(2) }
    assert_equal "20/20", complete.at_css(".set-tile__face--verso .set-tile__count").text
    assert_equal 3, complete.css(".set-tile__card .card.card--s").size
    assert_equal "+17", complete.at_css(".set-tile__more").text
    assert_select complete, ".set-tile__last .set-tile__last-card .card.card--s", 1
    assert_select complete, ".set-tile__face--verso > .set-tile__cta", "View the album"
    assert_equal "Horror, theme, 20 cards out of 20, complete", complete.at_css("> .visually-hidden").text
    small = browser_tiles.last
    assert_equal [ 2, 0 ], [ small.css(".set-tile__card").size, small.css(".set-tile__missing").size ]
  end

  test "with complete sets alone, EN COURS says none is in progress and shows no complete set" do
    entry_season
    player = accounts_players(:player)
    portal = named("franchise", "Portal", 2)
    halo = named("franchise", "Halo", 3)
    hold_all(player, portal)
    sign_in(player)

    get_in_progress(locale: :fr)

    assert_select "turbo-frame#set-entry-in-progress > p.set-entry__empty", "Aucun set en cours pour l'instant. Parcourez tous les sets pour en choisir un."
    assert_empty tiles
    assert_select "a.set-tile", false

    Game::Holding.where(player_id: player.id).delete_all
    hold_all(player, halo.first(2))

    get_in_progress

    assert_equal [ "Halo" ], tile_rows.map(&:first)
    assert_select ".set-entry__empty", false
  end

  test "more than six sets in progress show six tiles and a See all link to the screen filtered on them; six or fewer, no link; the same queries with three as with forty" do
    entry_season(540)
    player = accounts_players(:player)
    sets = (1..45).map { theme("theme-#{it}", 12) }
    hold_all(player, sets.first(3).flat_map { it.first(2) })
    sign_in(player)

    three = count_queries { get_in_progress }
    assert_equal [ "2/12" ] * 3, tile_rows.map(&:last)
    assert_empty see_all

    hold_all(player, sets[3, 3].flat_map { it.first(2) })
    get_in_progress
    assert_equal 6, tiles.size
    assert_empty see_all

    hold_all(player, sets[6, 34].flat_map { it.first(2) } + sets[40, 5].flatten)
    forty = count_queries { get_in_progress }
    assert_equal 6, tiles.size
    assert_equal three, forty
    # Player lookup, season; the standings, the sets named, their cards and
    # the faces of those shown; the themes' names; the player's goals.
    assert_equal 8, forty
    link = see_all.sole
    assert_equal [ "See all", "See all, sets in progress", "/en/library/sets?state%5B%5D=in_progress" ], [ link.text.squish, link["aria-label"], link["href"] ]
    assert_select "a.button--secondary, .set-more", false
  end

  test "EN COURS opened as a page leads to the entry" do
    sign_in(accounts_players(:player))

    get library_in_progress_path(locale: :en)

    assert_redirected_to library_path(locale: :en)
  end

  test "a ranked set's tile carries one tick per rank by its size, each with its mark and its place, and its reached rank in its head" do
    entry_season
    player = accounts_players(:player)
    sets = { "Tiny" => 3, "Small" => 7, "Roguelike" => 40, "Huge" => 250 }.to_h do |name, size|
      members = take(size)
      insert_ranked_theme(members, key: name.downcase, season: @season)
      [ name, members ]
    end
    hold_all(player, sets["Tiny"].first(2) + sets["Small"].first(2) + sets["Roguelike"].first(22) + sets["Huge"].first(30))
    sign_in(player)

    get_in_progress

    ticks = ->(name) { tile(name).css(".set-row__tick").map { [ it["class"][/--(\w+)/, 1], it["data-tier-at"], it.classes.include?("is-reached") ] } }
    assert_empty ticks.("Tiny")
    assert_equal [ [ "master", "0.5714", false ] ], ticks.("Small")
    assert_equal [ [ "adept", "0.25", true ], [ "expert", "0.5", true ], [ "master", "0.75", false ] ], ticks.("Roguelike")
    assert_equal [ [ "novice", "0.1", true ], [ "apprentice", "0.252", false ], [ "adept", "0.5", false ], [ "expert", "0.752", false ], [ "master", "0.9", false ] ],
      ticks.("Huge")
    sets.each_key do |name|
      tile = tile(name)
      assert_equal tile.css(".set-row__tick").map { it["class"][/--(\w+)/, 1] },
        tile.css(".set-row__tick > .set-row__tick-mark > svg.rank-mark.rank-mark--fine").map { it["class"][/rank-mark--(?!fine)(\w+)/, 1] }
      assert_equal name != "Tiny", tile.at_css(".set-tile__track").classes.include?("set-tile__track--tiered"), name
      assert_equal "tier-ticks", tile.at_css(".set-tile__track")["data-controller"]
    end
    assert_select ".set-row__figure, .set-album__figure", false

    roguelike = tile("Roguelike")
    assert_equal "Expert", roguelike.at_css(".set-chip--rank.tier-tone--expert").text
    assert_equal "Only 8 more for Master", roguelike.at_css(".set-tile__next").text.squish
    assert_equal [ %w[adept reached], %w[expert reached], %w[master next], %w[complete later] ],
      roguelike.css(".set-tile__node").map { [ it["class"][/tier-tone--(\w+)/, 1], it["class"][/set-tile__node--(\w+)/, 1] ] }
    assert_equal "Roguelike, theme, 22 cards out of 40, expert tier, master at 30", sentence("Roguelike")
    assert_equal "No tier", tile("Small").at_css(".set-chip--rank").text
    assert_select "[style]", false
  end

  test "the entry costs the same queries with three sets started or forty" do
    entry_season(540)
    player = accounts_players(:player)
    sets = (1..45).map { theme("theme-#{it}", 12) }
    hold_all(player, sets.first(3).flat_map { it.first(2) })
    sign_in(player)

    three = count_queries { get library_path(locale: :en) }

    hold_all(player, (sets[3, 37] - [ sets[13] ]).flat_map { it.first(2) })
    forty = count_queries { get library_path(locale: :en) }
    assert_equal three, forty
    # Player lookup, season, unique cards and the season's count, the latest
    # cards gained and their faces, the rarity legend and its copies, the sets'
    # total; the tab bar's trades and invitations waiting and the player's
    # avatar; the player's own sets, read once with their Steam library set,
    # and goals; with no goal, the sets suggested, their standings and the
    # themes' names.
    assert_equal 20, forty
  end

  test "the way to all the cards fans the three cards gained last, the latest on top" do
    entry_season(10)
    player = accounts_players(:player)
    first, second, third, fourth = @cards.first(4)
    hold(player, first, gained_at: 4.days.ago)
    hold(player, second, gained_at: 1.day.ago)
    hold(player, third, gained_at: 3.days.ago)
    hold(player, fourth, gained_at: 2.days.ago)
    sign_in(player)

    get library_path(locale: :en)

    assert_equal [ second, fourth, third ].map { title(it) }, css_select(".all-cards-tile__card .card__title").map { it.text.strip }
    assert_select ".all-cards-tile__count", "4/10"
  end

  test "a player who holds no card sees the ways to all the cards and all the sets and a line pointing to them; a visitor is sent to the landing" do
    entry_season
    %w[horror pirates cosy roguelike rpg].each { theme(it, 20) }
    sign_in(accounts_players(:player))

    get library_path(locale: :fr)

    assert_equal [ "Objectifs", "Mes sets" ], css_select(".set-entry h2").map(&:text)
    assert_select "a.all-cards-tile[href='/fr/library/cards']" do
      assert_select ".all-cards-tile__title", "Toutes mes cartes"
      assert_select ".all-cards-tile__count", "0/300"
      assert_select ".all-cards-tile__fan", false
      assert_select ".all-cards-tile__open", "Ouvrir"
    end
    assert_select "section#goals + a.all-cards-tile + a.all-cards-tile[href='/fr/library/sets'] + turbo-frame#set-entry-in-progress[src='/fr/library/in-progress'] + section.custom-sets"
    assert_select "#goals p.goals__empty", "Aucun objectif. Ouvrez l'album d'un set et marquez-le comme objectif."
    assert_select "#goals .goal-suggestions, #goals .goals__list", false

    get_in_progress(locale: :fr)
    assert_select "#set-entry-in-progress-title, .set-tile", false
    assert_select "turbo-frame#set-entry-in-progress > p.set-entry__empty", "Aucun set en cours pour l'instant. Parcourez tous les sets pour en choisir un."

    delete session_path(locale: :fr)
    get library_path(locale: :en)
    assert_redirected_to home_path(locale: :en)
    assert_response :see_other
    assert_nil flash[:alert]
    get library_sets_path(locale: :en)
    assert_redirected_to home_path(locale: :en)
    get_in_progress
    assert_redirected_to home_path(locale: :en)
  end

  test "a visitor is sent from a set's album to the landing, and reads the grid of every card" do
    entry_season
    theme("roguelike", 20)

    get library_set_path(locale: :fr, kind: "theme", key: "roguelike")
    assert_redirected_to home_path(locale: :fr)
    assert_response :see_other

    get library_cards_path(locale: :en)
    assert_response :success
    assert_select ".top-bar a.top-bar__home[href='/en']"
    assert_select ".top-bar a.top-bar__bridge[href='/en']"
    assert_select "a[href='/en/library'], a[href^='/en/library/theme/']", false
  end

  test "the sets closest to a tier lead, a set touched once stays off the entry" do
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

    get_in_progress(locale: :fr)

    assert_equal [ [ "Halo", "Franchise", "Aucun palier", "2/3" ], [ "Roguelike", "Thème", "Bronze", "12/62" ] ], tile_rows
    assert_equal "Roguelike, thème, 12 cartes sur 62, palier bronze, argent à 16", sentence("Roguelike")
    assert_nil tile("Pirates")
  end

  test "a game held only in an earlier edition counts in the published season's set" do
    entry_season
    portal = Catalog::CardSeason.insert_all!([ { card_id: catalog_cards(:portal).id, season_id: @season.id, prestige_score: 0.9, rating: 95 } ],
      returning: :id).rows.flatten.sole
    others = take(19)
    insert_theme([ portal ] + others, key: "puzzle", season: @season)
    player = accounts_players(:player)
    hold(player, catalog_card_seasons(:portal_one).id, 1)
    hold_all(player, [ others.first ])
    sign_in(player)

    get_in_progress

    assert_equal [ [ "Puzzle", "Theme", "Bronze", "2/20" ] ], tile_rows
  end

  # ---- All sets ----

  def browser_tiles = css_select("ul#set-browser-tiles > li > a.set-tile")

  # The tiles of the screen as [ name, kind, rank, "owned/total" ].
  def browser_rows
    browser_tiles.map { [ it.at_css(".set-tile__name").text, it.at_css(".set-tile__kind").text, it.at_css(".set-chip--rank")&.text, it.at_css(".set-tile__count")&.text ] }
  end

  test "All sets lists every set behind its filter row: in progress closest first, then not started by name, then complete; none framed in gold" do
    entry_season
    player = accounts_players(:player)
    halo = named("franchise", "Halo", 3)
    roguelike = theme("roguelike", 62)
    theme("pirates", 20)
    theme("horror", 20)
    portal = named("franchise", "Portal", 2)
    hold_all(player, halo.first(2) + roguelike.first(29) + portal)
    sign_in(player)

    get library_sets_path(locale: :en)

    assert_response :success
    assert_select "title", "All sets · Gameble"
    assert_select "h1.visually-hidden", "All sets"
    assert_select ".top-bar__title", "Collection"
    assert_select ".top-bar__end .collection-status .collection-status__value", "33 / 300"
    assert_select ".set-browser[data-controller=last-album][data-action='turbo:frame-load->last-album#mark']"
    assert_equal %w[Halo Roguelike Horror Pirates Portal], browser_rows.map(&:first)
    assert_equal [ [ "Halo", "Franchise", "No tier" ], [ "Portal", "Franchise", "Complete" ] ], browser_rows.values_at(0, 4).map { it.first(3) }
    assert_select "a.set-tile--closest", false
    assert_equal "/en/library/franchise/halo", browser_tiles.first["href"]

    assert_select "form.filters[action='/en/library/sets'][method=get][role=search][data-controller=collection-filters][data-turbo-frame=collection-results]" do
      assert_select "label.visually-hidden[for=collection-search]", "Search by name or kind"
      assert_select "input[type=search][name=q]#collection-search[maxlength='100'][data-collection-filters-target=search]"
      assert_select "a.filters__clear[hidden][href='/en/library/sets']", "Clear all"
    end
    assert_equal %w[#filters-kind #filters-state #filters-tier], css_select("ul.filter-row a.filter-row__pastille").map { it["href"] }
    assert_select "ul.filter-row .filter-row__count[hidden]", 3
    assert_equal %w[theme franchise], css_select("dialog#filters-kind [data-group=kind] input[name='kind[]']").map { it["value"] }
    assert_equal %w[not_started in_progress complete], css_select("dialog#filters-state [data-group=state] input[name='state[]']").map { it["value"] }
    assert_equal %w[novice apprentice adept expert master], css_select("dialog#filters-tier [data-group=tier] input[name='tier[]']").map { it["value"] }
    assert_select "dialog#filters-state .filter-chip__text", "In progress"
    assert_select "dialog#filters-goals", false
    assert_select "turbo-frame#collection-results[target=_top][data-controller=next-page][data-turbo-action=replace] > p#collection-results-status[role=status]", "5 sets shown."
    assert_select "#collection-pages", false
    assert_select "[style]", false
  end

  test "a filter narrows All sets from the URL, OR within a group, AND across groups; the row counts it and offers Clear all" do
    entry_season
    player = accounts_players(:player)
    halo = named("franchise", "Halo", 3)
    roguelike = theme("roguelike", 62)
    portal = named("franchise", "Portal", 2)
    theme("horror", 20)
    hold_all(player, halo.first(2) + roguelike.first(29) + portal)
    sign_in(player)

    get library_sets_path(locale: :en, kind: [ "franchise" ], state: %w[in_progress complete])

    assert_equal %w[Halo Portal], browser_rows.map(&:first)
    assert_select "dialog#filters-kind input[name='kind[]'][value=franchise][checked]"
    assert_select "dialog#filters-kind input[name='kind[]'][value=theme]:not([checked])"
    assert_equal %w[1 2], css_select("ul.filter-row .filter-row__count:not([hidden]) [data-pastille-number]").map(&:text)
    assert_select "a.filters__clear:not([hidden])"
    assert_select "#collection-results-status", "2 sets shown."

    get library_sets_path(locale: :en, kind: [ "theme" ], state: [ "complete" ])
    assert_empty browser_tiles
    assert_select "p.collection-grid__empty", "No set matches these filters."
    assert_select "a.filters__clear:not([hidden])"

    get library_sets_path(locale: :en, state: [ "foo" ], kind: [ "nope" ], tier: "bronze")
    assert_response :success
    assert_equal 4, browser_tiles.size
    assert_select "a.filters__clear[hidden]"

    get library_sets_path(locale: :en, state: { "x" => "y" }, kind: 3, q: { "x" => "y" })
    assert_response :success
    assert_equal 4, browser_tiles.size
  end

  test "the search finds a set by name or kind, started or not, name-prefix first, accents ignored, combined with the filters" do
    entry_season
    player = accounts_players(:player)
    souls = theme("souls_like", 10)
    %w[roguelike rpg horror].each { theme(it, 10) }
    complete = named("franchise", "Halo", 3)
    hold_all(player, souls.first(1))
    hold_all(player, complete, gained_at: 1.day.ago)
    sign_in(player)

    get library_sets_path(locale: :fr, q: " souls ")
    assert_select "input[type=search][name=q][value=souls]"
    assert_equal [ [ "Souls-like", "Thème", "Bronze", "1/10" ] ], browser_rows
    assert_equal "/fr/library/theme/souls_like", browser_tiles.sole["href"]
    assert_select "#collection-results-status", "1 set affiché."

    get library_sets_path(locale: :fr, q: "ZZZ")
    assert_empty browser_tiles
    assert_select "p.collection-grid__empty", "Aucun set ne correspond à ces filtres."
    assert_select "a.filters__clear:not([hidden])", "Tout effacer"

    get library_sets_path(locale: :fr, q: "HÂLO")
    assert_equal [ [ "Halo", "Franchise", "Complet", "3/3" ] ], browser_rows
    assert_equal "Halo, franchise, 3 cartes sur 3, complet", browser_tiles.sole.at_css("> .visually-hidden").text

    get library_sets_path(locale: :en, q: "r")
    assert_equal [ "Roguelike", "RPG", "Halo", "Horror" ], browser_rows.map(&:first)

    get library_sets_path(locale: :en, q: "r", state: [ "complete" ])
    assert_equal [ "Halo" ], browser_rows.map(&:first)

    get library_sets_path(locale: :en, q: "a" * 300)
    assert_select "input[name=q][value=?]", "a" * 100
  end

  test "a set the player has not started is a tile: silhouettes, no tier, the path from zero, Nothing collected for a large one" do
    entry_season
    player = accounts_players(:player)
    named("franchise", "Portal", 3)
    theme("roguelike", 62)
    sign_in(player)

    get library_sets_path(locale: :en, q: "po")
    small = browser_tiles.sole
    assert_equal "Portal", small.at_css(".set-tile__name").text
    assert_equal [ 3, 0 ], [ small.css(".set-tile__missing").size, small.css(".set-tile__card").size ]
    assert_select small, ".set-chip--rank.set-chip--none", "No tier"
    assert_equal "Only 3 more for Complete", small.at_css(".set-tile__next").text.squish
    assert_equal [ [ "complete", "next", nil, "Complete", "3" ] ], path(small)

    get library_sets_path(locale: :en, q: "rogue")
    large = browser_tiles.sole
    assert_equal "Nothing collected yet", large.at_css(".set-tile__nothing").text
    assert_equal "0/62", large.at_css(".set-tile__face--verso .set-tile__count").text
    assert_equal [ nil, "0", "0", "0" ], path(large).map { it[2] }
    assert_select large, ".set-tile__last", false
    assert_select large, ".set-tile__face--verso > span.button.set-tile__cta"
  end

  test "All sets pages its tiles twenty-four at a time: numbered links keep the filters, a stream appends the next page in order" do
    entry_season(120)
    player = accounts_players(:player)
    (1..30).each { theme("page-#{format("%02d", it)}", 4) }
    sign_in(player)

    get library_sets_path(locale: :en, q: "page")

    assert_equal 24, browser_tiles.size
    assert_equal (1..24).map { "Page-#{format("%02d", it)}" }, browser_rows.map(&:first)
    assert_select "#collection-results-status", "30 sets shown."
    assert_select "nav#collection-pages[aria-label='Pages of sets'][data-next-page-target=pages] a[rel=next][href*='page=2'][href*='q=page']"

    get library_sets_path(locale: :en, q: "page", page: 2)
    assert_equal (25..30).map { "Page-#{it}" }, browser_rows.map(&:first)

    get library_sets_path(locale: :en, q: "page", page: 2), headers: STREAM

    assert_response :success
    assert_equal Mime[:turbo_stream], response.media_type
    assert_equal %w[append update replace], css_select("turbo-stream").map { it["action"] }
    appended = css_select("turbo-stream[action=append][target=set-browser-tiles] template > li > a.set-tile")
    assert_equal (25..30).map { "Page-#{it}" }, appended.map { it.at_css(".set-tile__name").text }
    assert_equal "Sets 25 to 30 of 30 shown.", css_select("turbo-stream[action=update][target=collection-results-status] template").sole.text
    assert_select "turbo-stream[action=replace][target=collection-pages] template > nav#collection-pages a[rel=prev][href*='q=page']"
    assert_select "turbo-stream form", false

    get library_sets_path(locale: :en, q: "page", page: 9)
    assert_empty browser_tiles
    assert_select "p.collection-grid__empty", "No more sets here: the list ends on an earlier page. Go back to the last page."
  end

  test "All sets holds the player's own sets and goals: a My sets kind, a goal chip, the tile's goal mark" do
    entry_season(30)
    player = accounts_players(:player)
    create_custom_set(player, name: "Mes favoris", card_ids: Catalog::CardSeason.where(id: take(3)).pluck(:card_id))
    theme("roguelike", 5)
    Game::AddGoal.new.call(player:, kind: "theme", key: "roguelike").value!
    sign_in(player)

    get library_sets_path(locale: :fr)

    assert_includes css_select("dialog#filters-kind input[name='kind[]']").map { it["value"] }, "mine"
    assert_select "dialog#filters-kind .filter-chip__text", "Mes sets"
    assert_equal %w[#filters-kind #filters-state #filters-tier #filters-goals], css_select("ul.filter-row a.filter-row__pastille").map { it["href"] }
    assert_select "dialog#filters-goals input[type=checkbox][name='goals[]'][value='theme:roguelike']"
    assert_select "ul#set-browser-tiles a.set-tile.set-tile--goal.goal-tone--1[href='/fr/library/theme/roguelike']"

    get library_sets_path(locale: :fr, kind: [ "mine" ])
    assert_equal [ "Mes favoris" ], browser_rows.map(&:first)
    assert_equal "Set perso · 3 jeux", browser_rows.sole.second

    get library_sets_path(locale: :fr, goals: [ "theme:roguelike" ])
    assert_equal [ "Roguelike" ], browser_rows.map(&:first)
  end

  test "with no season published All sets says so; a visitor is sent to the landing" do
    catalog_seasons(:one).update_columns(status: "draft", published_at: nil)
    get library_sets_path(locale: :en)
    assert_redirected_to home_path(locale: :en)

    sign_in(accounts_players(:player))
    get library_sets_path(locale: :en, state: [ "complete" ])

    assert_response :success
    assert_select ".collection-none p.panel", "No season of cards is published yet."
    assert_select ".set-browser, form.filters, .collection-status", false
  end

  test "no set or card-season id reaches the entry, and its GET writes nothing" do
    entry_season
    player = accounts_players(:player)
    cards = theme("roguelike", 30) + theme("rpg", 30)
    hold_all(player, cards.first(5), gained_at: 1.minute.ago)
    sign_in(player)
    ids = Catalog::Set.where(season_id: @season.id).ids + Catalog::CardSeason.where(season_id: @season.id).ids

    assert_no_changes -> { [ Game::SetTier.count, Game::PlayerState.find_by!(player_id: player.id).attributes ] } do
      get library_sets_path(locale: :en, q: "r")
    end

    html = css_select("main").sole.to_html
    assert_select "main [data-id]", false
    ids.each do |id|
      assert_no_match(/\b#{id}\b/, html.gsub(/\d+\/\d+|\d+ (cards?|sets?) |out of \d+|at \d+|value="\d+"|max="\d+"|maxlength="\d+"/, ""))
    end

    assert_no_changes -> { [ Game::SetTier.count, Game::PlayerState.find_by!(player_id: player.id).attributes ] } do
      get_in_progress
    end

    assert_equal [ "5/30" ], tile_rows.map(&:last)
    html = css_select("turbo-frame").sole.to_html
    assert_select "[data-id]", false
    ids.each do |id|
      assert_no_match(/\b#{id}\b/, html.gsub(/\d+\/\d+|\d+ (cards?|sets?) |out of \d+|at \d+|\+\d+|value="\d+"|max="\d+"|seed-\d+-\d+|board-\d+-\d+|data-card-art-[a-z-]+-value="\d+"|data-tilt-max-value="\d+"|data-tier-at="[\d.]+"|width="\d+"|height="\d+"|viewbox="[\d ]+"|\b(19|20)\d\d\b|[MmHhVvZz][\d.-]+|<b>\d+<\/b>|"set-tile__dot">\d+|"set-tile__node-required">\d+|il y a \d+|\d+ (minutes?|hours?|days?) ago/, ""))
    end
  end

  def earlier_edition(card_season_id, rarity:)
    card_id = Catalog::CardSeason.find(card_season_id).card_id
    Catalog::CardSeason.insert_all!([ { card_id:, season_id: catalog_seasons(:one).id, prestige_score: 0.5, rating: 90, rarity:, number: 900 } ],
      returning: :id).rows.flatten.sole
  end

  def editions_badges = css_select(".collection-slot__editions").map(&:text)

  def tile_hrefs = css_select(".collection-grid a.card-link").map { it["href"][%r{/seasons/\d+}] }

  def two_editions(season, player)
    epic = Catalog::CardSeason.where(season_id: season.id, rarity: "epic").order(:number, :id).first.id
    rare = earlier_edition(epic, rarity: "rare")
    hold(player, rare, 1, gained_at: 3.hours.ago)
    hold(player, epic, 1, gained_at: 4.hours.ago)
    Game::PlayerState.where(player_id: player.id).update_all(collection_seen_up_to: 2.hours.ago)
    [ epic, rare ]
  end

  test "a game held in two editions is one tile at its best edition, its copies and editions across both, at the same queries" do
    season = publish_sets_draft
    player = accounts_players(:player)
    epic, = two_editions(season, player)
    sign_in(player)

    assert_request_queries(21) { get library_cards_path(locale: :en, state: %w[owned]) }

    assert_equal [ [ :owned, title(epic), "x2", nil ] ], slots
    assert_equal [ "/seasons/#{season.number}" ], tile_hrefs
    assert_select ".collection-slot .card.card--rarity-epic"
    assert_select ".collection-slot__editions[aria-hidden=true]", "2 ed."
    assert_select ".collection-slot .visually-hidden", "2 editions"
    assert_select ".collection-status__value", "1 / 150"
    assert_equal({ "Total cards" => "2", "Duplicates" => "1", "Common" => "0", "Uncommon" => "0", "Rare" => "0", "Epic" => "1", "Legendary" => "0" },
      report)
    assert_select ".report--fold summary .report__line", "2 cards · 1 duplicate"
    assert_select "[style]", 0

    get library_cards_path(locale: :fr, state: %w[owned])
    assert_equal [ "2 éd." ], editions_badges
    assert_select ".collection-slot .visually-hidden", "2 éditions"
  end

  test "a game held in one edition shows no edition count" do
    season = publish_sets_draft
    player = accounts_players(:player)
    hold(player, season_cards(season).first, 2)
    sign_in(player)

    get library_cards_path(locale: :en, state: %w[owned])
    assert_equal [ "x2" ], slots.map(&:third)
    assert_empty editions_badges
  end

  test "the filters read the game across its editions: its best rarity, duplicates over both, new through either" do
    season = publish_sets_draft
    player = accounts_players(:player)
    epic, rare = two_editions(season, player)
    Game::Holding.where(player_id: player.id, card_season_id: rare).update_all(last_gained_at: 1.minute.ago)
    sign_in(player)

    get library_cards_path(locale: :en, state: %w[owned], rarity: %w[rare])
    assert_empty slots
    get library_cards_path(locale: :en, state: %w[owned], rarity: %w[epic])
    assert_equal [ title(epic) ], slots.map(&:second)

    get library_cards_path(locale: :en, state: %w[duplicates])
    assert_equal [ title(epic) ], slots.map(&:second)

    get library_cards_path(locale: :en, state: %w[new])
    assert_equal [ [ :owned, title(epic), "x2", "New" ] ], slots
    seen = Game::Holding.find_by!(player_id: player.id, card_season_id: rare).last_gained_at
    assert_equal seen.utc.iso8601(6), css_select("[data-controller=collection-seen]").sole["data-collection-seen-up-to-value"]

    get library_cards_path(locale: :en, state: %w[missing])
    assert_not_includes slots.map(&:second), title(epic)
  end

  test "a game held twice at one rarity shows the published season's edition" do
    season = publish_sets_draft
    player = accounts_players(:player)
    card = Catalog::CardSeason.where(season_id: season.id, rarity: "rare").order(:number, :id).first.id
    hold(player, earlier_edition(card, rarity: "rare"), 1)
    hold(player, card, 1)
    sign_in(player)

    get library_cards_path(locale: :en, state: %w[owned])
    assert_equal [ "/seasons/#{season.number}" ], tile_hrefs
  end

  test "publishing a season keeps every owned tile, the unique cards and the RAPPORT; a game gone from the catalog keeps its tile" do
    season = publish_sets_draft
    player = accounts_players(:player)
    held = season_cards(season).first(30)
    held.each { hold(player, it, 1) }
    sign_in(player)
    get library_cards_path(locale: :en)
    before = report

    newer = publish_sets_draft
    get library_cards_path(locale: :en)

    assert_equal held.map { title(it) }.sort, slots.first(30).map(&:second).sort
    assert_equal [ :owned ] * 30, slots.first(30).map(&:first)
    assert_equal [ :not_owned ] * 30, slots.drop(30).map(&:first)
    assert_equal [ "/seasons/#{season.number}" ] * 30, tile_hrefs.first(30)
    assert_equal [ "/seasons/#{newer.number}" ] * 30, tile_hrefs.drop(30)
    assert_select ".collection-status__value", "30 / 150"
    assert_select "progress.collection-status__bar[value='30'][max='150']"
    assert_equal before, report

    get library_cards_path(locale: :en, state: %w[owned])
    assert_equal 30, slots.size
    assert_select "turbo-frame#collection-results > p[role=status]", "30 cards shown."
  end

  test "more games held than the season's cards fill the bar at most" do
    season = publish_sets_draft
    player = accounts_players(:player)
    season_cards(season).each { hold(player, it, 1) }
    hold(player, catalog_card_seasons(:portal_one).id, 1)
    sign_in(player)

    get library_path(locale: :en)
    assert_select ".collection-status__value", "151 / 150"
    assert_select "progress.collection-status__bar[value='150'][max='150']"
  end

  test "a visitor sees the published season's tiles, with no edition count and no unique cards" do
    season = publish_sets_draft
    two_editions(season, accounts_players(:player))

    get library_cards_path(locale: :en)
    assert_equal season_cards(season).first(60).map { [ :plain, title(it), year(it) ] }, slots
    assert_empty editions_badges
    assert_select ".collection-status", false
  end

  def steam_library_section = css_select("section.steam-library").sole

  test "a synced Steam library set has its section after MES SETS: the sync date in its head, then its tile with its kind line, owned over total and no tier" do
    player = accounts_players(:player)
    library = create_library_set(player, card_ids: fixture_card_ids.first(3), synced_at: Time.zone.local(2026, 10, 29, 5))
    hold_all(player, [ catalog_card_seasons(:common_card_one).id ])
    create_custom_set(player)
    sign_in(player)

    get library_path(locale: :fr)

    assert_select ".set-entry > turbo-frame#set-entry-in-progress + section.custom-sets + section.steam-library[aria-labelledby=steam-library-title]"
    assert_equal [ "Objectifs", "Mes sets", "Ma bibliothèque Steam" ], css_select(".set-entry h2").map(&:text)
    assert_equal 1, css_select(".custom-sets a.set-tile").size
    within_section = steam_library_section
    head = within_section.at_css("> div.steam-library__head")
    assert_equal "Ma bibliothèque Steam", head.at_css("> h2#steam-library-title").text
    assert_equal "Synchronisée avec Steam le 29 octobre 2026", head.at_css("> p.steam-library__note").text.squish
    assert_equal "29 octobre 2026", head.at_css("p.steam-library__note b").text
    assert_nil within_section.at_css(".steam-library__not-shared")
    tile = within_section.at_css("div.steam-library__head + ul.set-tiles > li > a.set-tile[href='/fr/library/custom-sets/#{library.token}']")
    recto = tile.at_css(".set-tile__face--recto")
    assert_equal "Ma bibliothèque Steam", recto.at_css(".set-tile__name").text
    assert_equal "Steam · 3 jeux du catalogue", recto.at_css(".set-tile__kind").text
    assert_equal "1/3", recto.at_css(".set-tile__head > .set-tile__count").text.squish
    assert recto.at_css("progress.set-row__bar[value='1'][max='3']")
    assert_equal "Plus que 2 pour Complet", recto.at_css(".set-tile__next").text.squish
    assert_equal %w[complete], tile.css(".set-tile__node").map { it["class"][/tier-tone--(\w+)/, 1] }
    assert_equal "Ma bibliothèque Steam, 1 carte sur 3", tile.at_css("> .visually-hidden").text
    assert_select ".steam-library .set-chip--rank, .steam-library .set-row__tick, .steam-library .set-tile--closest", false
    assert_select "[style]", false
  end

  test "a library Steam does not share reads so, with the last sync date, in English too" do
    player = accounts_players(:player)
    create_library_set(player, synced_at: Time.zone.local(2026, 10, 1, 5), library_private_since: 2.days.ago)
    sign_in(player)

    get library_path(locale: :en)

    assert_equal "Last sync: October 1, 2026", steam_library_section.at_css(".steam-library__head > p.steam-library__note").text.squish
    assert_equal "October 1, 2026", steam_library_section.at_css("p.steam-library__note b").text
    assert_equal "Steam does not share your library. Make the game details of your Steam profile public.",
      steam_library_section.at_css("div.steam-library__head + p.steam-library__not-shared").text.squish
    assert steam_library_section.at_css("p.steam-library__not-shared + ul.set-tiles")
    assert_equal "My Steam library, 0 cards out of 3", steam_library_section.at_css("a.set-tile > .visually-hidden").text

    get library_path(locale: :fr)
    assert_equal "Dernière synchronisation\u202F: 1er octobre 2026", steam_library_section.at_css("p.steam-library__note").text.strip
    assert_equal "1er octobre 2026", steam_library_section.at_css("p.steam-library__note b").text
    assert_equal "Steam ne partage pas votre bibliothèque. Rendez publics les détails de jeux de votre profil Steam.",
      steam_library_section.at_css("p.steam-library__not-shared").text.squish
  end

  test "a library private at its first sync shows the not-shared line and no head note" do
    player = accounts_players(:player)
    create_library_set(player, card_ids: [], synced_at: nil, library_private_since: 1.day.ago)
    sign_in(player)

    get library_path(locale: :en)

    assert_equal "Steam does not share your library. Make the game details of your Steam profile public.",
      steam_library_section.at_css("div.steam-library__head + p.steam-library__not-shared").text.squish
    assert_nil steam_library_section.at_css(".steam-library__note")
    assert_equal "Steam · 0 catalog games", steam_library_section.at_css(".set-tile__face--recto .set-tile__kind").text
  end

  test "no section for a library set never synced, nor for a player without one" do
    player = accounts_players(:player)
    sign_in(player)

    get library_path(locale: :en)
    assert_select ".steam-library", false

    create_library_set(player, synced_at: nil)
    get library_path(locale: :en)
    assert_select ".steam-library", false
    assert_select ".custom-sets a.set-tile", false
  end
end
