require "test_helper"
require_relative "../support/catalog_seeds"
require_relative "../support/library_requests"

# The collection of the whole season (CAP-6, story 10.1; DESIGN.md,
# Collection): the top bar's unique cards, the sets of one kind as progress
# rows under "Whole season", the RAPPORT, the genre chips, the grid of owned
# faces and missing slots sixty to a page, the NOUVEAU tag and its watermark
# post; for a player, a visitor and a banned player; the queries of a
# request.
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

  test "a player sees their unique cards, the tomes' progress, the RAPPORT and the first sixty cards of the season" do
    season = publish_sets_draft
    player = accounts_players(:player)
    cards = season_cards(season)
    # The first three of the grid (numbers are shuffled at publication), and
    # a card of a tome held at 0.
    first, second, third = cards.first(3)
    hold(player, first, 1)
    hold(player, second, 3)
    hold(player, third, 1)
    hold(player, (set_members(season, "action-2") - cards.first(3)).first, 0)
    tomes = %w[action-1 action-2 action-3 rpg-1].map { (set_members(season, it) & [ first, second, third ]).size }
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
    assert_equal [ [ "Tomes", "/en/library", "true" ], [ "Publishers", "/en/library?kind=publisher", nil ],
      [ "Best rated of the year", "/en/library?kind=best_of_year", nil ] ],
      css_select(".collection-kinds a.collection-kind").map { [ it.text, it["href"], it["aria-current"] ] }
    assert_equal [ [ "Whole season", "3/150" ], [ "Action · Tome 1", "#{tomes[0]}/25" ], [ "Action · Tome 2", "#{tomes[1]}/25" ],
      [ "Action · Tome 3", "#{tomes[2]}/25" ], [ "RPG · Tome 1", "#{tomes[3]}/44" ] ], set_rows
    assert_equal "Whole season", current_row
    assert_equal [ "/en/library", "/en/library/tome/action-1", "/en/library/tome/action-2", "/en/library/tome/action-3", "/en/library/tome/rpg-1" ],
      css_select(".collection-sets .set-row").map { it["href"] }
    assert_select ".collection-sets .set-row .visually-hidden", "#{tomes[1]} #{tomes[1] == 1 ? "card" : "cards"} owned out of 25"
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
    # browsing the card's tome (a card in no tome, without a set).
    slugs = Catalog::CardSeason.where(id: cards.first(60)).includes(:card).index_by(&:id).transform_values { it.card.slug }
    tome_of = %w[action-1 action-2 action-3 rpg-1].flat_map { |key| set_members(season, key).map { [ it, key ] } }.to_h
    links = css_select(".collection-grid > li > a.card-link")
    assert_equal cards.first(60).map { |id|
      "/en/cards/#{slugs.fetch(id)}/seasons/#{season.number}#{"?set_key=#{tome_of[id]}&set_kind=tome" if tome_of[id]}"
    }, links.map { it["href"] }
    assert links.any? { !it["href"].include?("?") }, "a card in no tome"
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

  test "on the whole season a held card's link and a missing one's name the card's tome, so its detail browses it" do
    season = publish_sets_draft
    player = accounts_players(:player)
    page_one = season_cards(season).first(60)
    held, missing = page_one.select { it.in?(set_members(season, "rpg-1")) }.first(2)
    assert missing, "two cards of rpg-1 on the first page"
    hold(player, held, 1)
    sign_in(player)
    href = ->(id) { "/en/cards/#{Catalog::CardSeason.find(id).card.slug}/seasons/#{season.number}?set_key=rpg-1&set_kind=tome" }

    get library_path(locale: :en, state: %w[all])

    assert_select ".collection-grid a.card-link[href=?] .card", href.(held)
    assert_select ".collection-grid a.card-link[href=?] .missing-slot", href.(missing)

    # A set's page names its own set, never the tome.
    get library_set_path(locale: :en, kind: "publisher", key: "p", state: %w[all])
    assert_equal [ "?set_key=p&set_kind=publisher" ] * 5, css_select(".collection-grid a.card-link").map { it["href"][/\?.*/] }
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
    assert_equal [ [ "Whole season", "0/150" ], [ "Action · Tome 1", "0/25" ], [ "Action · Tome 2", "0/25" ], [ "Action · Tome 3", "0/25" ], [ "RPG · Tome 1", "0/44" ] ], set_rows
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
      get library_set_path(locale: :en, kind: "tome", key: "action-1")
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

  [ nil, "", "nope", [ "publisher" ] ].each do |kind|
    test "a kind of #{kind.inspect} lists the tomes" do
      publish_sets_draft

      get library_path(locale: :en), params: { kind: }.compact

      assert_response :success
      assert_select ".collection-kind[aria-current=true]", "Tomes"
      assert_equal 5, set_rows.size
    end
  end

  test "the other kinds list their sets, in their order, with their progress" do
    season = publish_sets_draft
    player = accounts_players(:player)
    card = set_members(season, "p").first
    hold(player, card, 1)
    sign_in(player)

    get library_path(locale: :fr, kind: "publisher")
    assert_select ".collection-kind[aria-current=true]", "Éditeurs"
    assert_equal [ [ "Toute la saison", "1/150" ], [ "P", "1/5" ] ], set_rows
    assert_equal "Toute la saison", current_row
    assert_equal [ "/fr/library?kind=publisher", "/fr/library/publisher/p" ], css_select(".collection-sets .set-row").map { it["href"] }

    get library_path(locale: :en, kind: "best_of_year")
    owned = [ card ]
    expected = %w[2015 2012 2011].map do |key|
      members = set_members(season, key)
      [ "Best rated of #{key}", "#{(members & owned).size}/#{members.size}" ]
    end
    assert_equal [ [ "Whole season", "1/150" ] ] + expected, set_rows
  end

  test "a kind without sets says so" do
    seed_published_sets([ [ "tome", "action-1", { "genre" => "action", "volume" => 1, "volumes" => 1 } ] ])

    get library_path(locale: :en, kind: "publisher")

    assert_response :success
    assert_equal [ [ "Whole season", "0/0" ] ], set_rows
    assert_select ".collection-sets__empty", "No publisher has earned a set this season, Brother."
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
    assert_equal "/en/library?shelf=3", css_select(".collection-sets .set-row").first["href"]
    assert_equal "/en/library/tome/action-101?shelf=3", css_select(".collection-sets .set-row")[1]["href"]

    get library_path(locale: :en, shelf: 9)
    assert_response :success
    assert_equal 1, set_rows.size
    assert_select ".collection-sets__empty", "This shelf stands empty, Brother. The tomes end on an earlier one."
    assert_select ".collection-sets .series-nav a[href='/en/library?shelf=3']", minimum: 1
  end

  test "the genre chips filter the grid, OR within the group; an unknown genre is ignored" do
    season = publish_sets_draft
    action = set_members(season, "action-1") + set_members(season, "action-2") + set_members(season, "action-3")
    rpg = set_members(season, "rpg-1")

    get library_path(locale: :fr, kind: "publisher", shelf: 1, state: %w[all])
    assert_equal [ "Action", "RPG" ], css_select("[data-group=genre] .filter-chip__text").map(&:text)
    assert_equal [ "genre[]" ], css_select("[data-group=genre] input").map { it["name"] }.uniq
    assert_equal [ "publisher" ], css_select("form.filters input[name=kind]").map { it["value"] }

    get library_path(locale: :en, genre: [ "rpg" ], state: %w[all])
    assert_equal [ "RPG" ], css_select("[data-group=genre] .filter-chip__box[checked]").map { it.parent.text.strip }
    assert_equal season_cards(season).select { it.in?(rpg) }.map { title(it) }, slots.map(&:second)

    get library_path(locale: :en, genre: [ "rpg", "action" ], state: %w[all])
    assert_equal season_cards(season).select { it.in?(rpg + action) }.first(60).map { title(it) }, slots.map(&:second)

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
    assert_select ".collection-none p.panel", "The shelves are bare, Brother: the Brotherhood has published no season of cards yet."
    assert_select ".collection, .collection-status", false
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

    # Player lookup, published season; the list: count, page, totals,
    # progress; the grid: genres, count (the season's cards, read again from
    # the query cache by the top bar; filtered by state it is its own query),
    # page, card views, the player's slots,
    # the cards' tomes (the whole season only: their links name them); the
    # figures: unique cards, copies per tier; the tab bar's trades waiting.
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
    assert_equal [ "Action · Tome 1", "Action · Tome 2", "Action · Tome 3", "RPG · Tome 1" ],
      css_select("[data-group=sets] .filter-chip__text").map(&:text)
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
    rpg = set_members(season, "rpg-1")
    action = set_members(season, "action-1")
    sample = (rpg.first(6) + action.first(6))
    sample.each { hold(player, it, 1) }
    sign_in(player)

    get library_path(locale: :en, genre: %w[rpg])
    assert_equal rpg.first(6).map { title(it) }.sort, slots.map(&:second).sort

    get library_path(locale: :en, genre: %w[rpg action])
    assert_equal sample.size, slots.size

    rarity = Catalog::CardSeason.where(id: sample).pick(:rarity)
    both = Catalog::CardSeason.where(id: sample, rarity:).count
    get library_path(locale: :en, genre: %w[rpg action], rarity: [ rarity ])
    assert_equal both, slots.size
    assert_operator both, :<, sample.size
    assert_select ".filters__count", /3/
  end

  test "the set chips filter the whole season's cards, OR within the group" do
    season = publish_sets_draft
    player = accounts_players(:player)
    a = set_members(season, "action-1").first(3)
    b = set_members(season, "rpg-1").first(2)
    (a + b).each { hold(player, it, 1) }
    sign_in(player)

    get library_path(locale: :en, sets: %w[tome:action-1 tome:rpg-1])
    assert_equal 5, slots.size
    assert_equal [ "Action · Tome 1", "RPG · Tome 1" ], css_select("[data-group=sets] .filter-chip__box[checked]").map { it.parent.text.strip }

    get library_path(locale: :en, sets: %w[tome:rpg-1])
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
    members = set_members(season, "action-1")
    hold(player, members[3], 1)
    sign_in(player)

    get library_set_path(locale: :en, kind: "tome", key: "action-1", rarity: Catalog::Rarity::TIERS.values.map(&:to_s))
    assert_equal [ title(members[3]) ], slots.map(&:second)
    assert_select ".filters__clear[href=?]", "/en/library/tome/action-1"
  end
end
