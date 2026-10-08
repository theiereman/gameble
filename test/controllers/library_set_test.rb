require "test_helper"
require_relative "../support/catalog_seeds"
require_relative "../support/library_requests"

# The collection of one set (CAP-6, story 10.1): its row current among its
# kind's, its cards in slot order, owned faces with their copies and missing
# slots naming their games, for a player and a visitor; its genres; the
# sets that are not found; the queries of a request.
class LibrarySetTest < ActionDispatch::IntegrationTest
  include CatalogSeeds
  include LibraryRequests

  setup do
    OmniAuth.config.test_mode = true
  end

  teardown do
    OmniAuth.config.mock_auth.delete(:steam)
    OmniAuth.config.test_mode = false
  end

  def title(card_season_id, locale = "en")
    Catalog::CardText.find_by!(card_id: Catalog::CardSeason.find(card_season_id).card_id, locale:).title
  end

  def year(card_season_id) = Catalog::CardSeason.find(card_season_id).card.release_date.year

  # The slots in order: [ :owned, title, "xn" ] or [ :missing, title, year ].
  def slots
    css_select(".collection-grid > li").map do |slot|
      if (card = slot.at_css(".card"))
        [ :owned, card.at_css(".card__title").text, slot.at_css(".collection-slot__copies").text ]
      else
        [ :missing, slot.at_css(".missing-slot__title").text, slot.at_css(".missing-slot__year").text.to_i ]
      end
    end
  end

  def current_row
    row = css_select(".collection-sets .set-row[aria-current=page]").sole
    [ row.at_css(".set-row__name").text, row.at_css(".set-row__count").text ]
  end

  test "a player sees the set's cards in slot order: faces with their copies, missing slots naming the rest" do
    season = publish_sets_draft
    player = accounts_players(:player)
    members = set_members(season, "action-1")
    hold(player, members[0], 1)
    hold(player, members[3], 2)
    hold(player, members[24], 1)
    hold(player, members[5], 0)
    sign_in(player)

    get library_set_path(locale: :en, kind: "tome", key: "action-1", state: %w[all])

    assert_response :success
    assert_select "title", "Action · Tome 1"
    assert_select "h1", "Action · Tome 1"
    assert_select ".top-bar__title", "Collection"
    assert_select ".collection-status__value", "3 / 150"
    assert_equal [ "Action · Tome 1", "3/25" ], current_row
    assert_select ".collection-kind[aria-current=true]", "Tomes"
    assert_equal [ "/en/library", "/en/library/tome/action-1", "/en/library/tome/action-2", "/en/library/tome/action-3", "/en/library/tome/rpg-1" ],
      css_select(".collection-sets .set-row").map { it["href"] }
    expected = members.each_with_index.map do |id, index|
      case index
      when 0, 24 then [ :owned, title(id), "x1" ]
      when 3 then [ :owned, title(id), "x2" ]
      else [ :missing, title(id), year(id) ]
      end
    end
    assert_equal expected, slots
    assert_select ".collection-grid .card.card--m", 3
    assert_select ".collection-slot__copies[aria-hidden=true] + .visually-hidden", "2 copies"
    assert_select "[style]", 0
    # A tome holds one genre: one genre chip.
    assert_equal [ "Action" ], css_select("[data-group=genre] .filter-chip__text").map(&:text)
    # Every face and missing slot leads to its card's detail in this season,
    # walking this set's grid as shown (its ◀ ▶, a card not held as the
    # faded back); "xn" stays outside the link.
    slugs = Catalog::CardSeason.where(id: members).includes(:card).index_by(&:id).transform_values { it.card.slug }
    links = css_select(".collection-grid > li > a.card-link")
    grid = { grid: { kind: "tome", key: "action-1", q: "", state: %w[all] } }.to_query
    assert_equal members.map { |id| "/en/cards/#{slugs.fetch(id)}/seasons/#{season.number}?#{grid}" },
      links.map { it["href"] }
    assert_equal members.map { |id| [ "false", id.in?([ members[0], members[3], members[24] ]) ? ".card" : ".missing-slot" ] },
      links.map { |link| [ link["data-turbo-prefetch"], link.at_css(".card") ? ".card" : ".missing-slot" ] }
    rarity = Catalog::CardViews.call([ members[3] ], locale: :en).fetch(members[3]).rarity
    assert_equal "#{title(members[3])}, #{I18n.t("catalog.rarity.#{rarity}", locale: :en)}, season #{season.number}", links[3]["aria-label"]
    # A face's link is named by its label; a missing slot's by its visible
    # text, so a screen reader says "Missing card".
    assert_equal members.map { |id| id.in?([ members[0], members[3], members[24] ]) }, links.map { it["aria-label"].present? }
    assert_equal "#{title(members[1])} #{year(members[1])} Missing card", links[1].text.squish
    assert_select ".collection-pages", false
  end

  test "a visitor sees the same set with every slot missing" do
    season = publish_sets_draft
    members = set_members(season, "action-1")
    hold(accounts_players(:player), members.first, 1, gained_at: 1.minute.ago)

    get library_set_path(locale: :en, kind: "tome", key: "action-1")

    assert_response :success
    assert_equal [ "Action · Tome 1", "0/25" ], current_row
    assert_select ".collection-grid .card, .collection-slot__new", false
    assert_equal members.map { |id| [ :missing, title(id), year(id) ] }, slots
    assert_select ".top-bar__end form.steam-sign-in"
  end

  test "each kind: a best of year with its genres, a publisher; the list is the set's kind" do
    season = publish_sets_draft

    get library_set_path(locale: :en, kind: "best_of_year", key: "2015")
    assert_select "h1", "Best rated of 2015"
    assert_equal [ "Best rated of 2015", "0/10" ], current_row
    assert_select ".collection-kind[aria-current=true]", "Best rated of the year"
    assert_equal set_members(season, "2015").map { title(it) }, slots.map(&:second)
    assert_equal "/en/library?kind=best_of_year", css_select(".collection-sets .set-row").first["href"]

    get library_set_path(locale: :fr, kind: "publisher", key: "p")
    assert_select "h1", "P"
    assert_equal [ "P", "0/5" ], current_row
    assert_select ".collection-kind[aria-current=true]", "Éditeurs"
  end

  test "a set's genre chips filter its cards, keep the list and offer no set group" do
    season = publish_sets_draft
    members = set_members(season, "2011")
    genres = members.to_h { |id| [ id, Catalog::CardViews.call([ id ], locale: :en).fetch(id).genre ] }

    get library_set_path(locale: :en, kind: "best_of_year", key: "2011", shelf: 1, state: %w[all])
    assert_equal [ "Action", "RPG" ], css_select("[data-group=genre] .filter-chip__text").map(&:text)
    assert_select "[data-group=sets]", false
    assert_select "form.filters[action=?]", "/en/library/best_of_year/2011"

    get library_set_path(locale: :en, kind: "best_of_year", key: "2011", genre: [ "rpg" ], state: %w[all])
    assert_equal members.select { genres[it] == "rpg" }.map { title(it) }, slots.map(&:second)
    assert_equal [ "Best rated of 2011", "0/10" ], current_row
  end

  test "in French the titles and words are French" do
    season = publish_sets_draft
    player = accounts_players(:player)
    members = set_members(season, "2011")
    Catalog::CardText.where(card_id: Catalog::CardSeason.find(members.first).card_id, locale: "fr").update_all(title: "La Graine")
    hold(player, members.second, 3)
    sign_in(player)

    get library_set_path(locale: :fr, kind: "best_of_year", key: "2011", state: %w[all])

    assert_select "h1", "Les mieux notés de 2011"
    assert_equal [ "Les mieux notés de 2011", "1/10" ], current_row
    assert_select ".collection-sets .set-row[aria-current=page] .visually-hidden", "1 carte possédée sur 10"
    assert_equal "La Graine", slots.first.second
    assert_select ".missing-slot .visually-hidden", { count: 9, text: "Carte manquante" }
    assert_select ".collection-slot__copies + .visually-hidden", "3 exemplaires"
    assert_select ".collection-sets .set-row", text: /Toute la saison/
  end

  test "the rows lead to their set at the list's page; the set's page lists that page, the current row marked" do
    seed_published_sets((1..60).map { |volume| [ "tome", "action-#{volume}", { "genre" => "action", "volume" => volume, "volumes" => 60 } ] })

    get library_set_path(locale: :en, kind: "tome", key: "action-55", shelf: 2)
    assert_response :success
    assert_equal [ "Action · Tome 55", "0/0" ], current_row
    assert_equal 11, css_select(".collection-sets .set-row").size
    assert_equal "/en/library?shelf=2", css_select(".collection-sets .set-row").first["href"]
    assert_equal "/en/library/tome/action-51?shelf=2", css_select(".collection-sets .set-row")[1]["href"]
    assert_select ".collection-grid__empty", "Nothing matches these filters."

    get library_set_path(locale: :en, kind: "tome", key: "action-55")
    assert_response :success
    assert_equal 51, css_select(".collection-sets .set-row").size
    assert_select ".collection-sets .set-row[aria-current]", false
  end

  test "the old shelf parameter, ?page, now pages the grid: the URL still opens the set" do
    season = publish_sets_draft

    get library_set_path(locale: :en, kind: "tome", key: "rpg-1", page: 1)

    assert_response :success
    assert_equal set_members(season, "rpg-1").map { title(it) }, slots.map(&:second)

    # An old bookmark's shelf page, past the grid's last: the past-the-end
    # line (not the empty-genre one) and the way back.
    get library_set_path(locale: :fr, kind: "tome", key: "rpg-1", page: 2)

    assert_response :success
    assert_empty slots
    assert_select ".collection-grid__empty", "Plus aucune carte ici : la grille s'arrête sur une page précédente. Revenez à la dernière page."
    assert_select ".collection-pages a[rel=prev][href=?]", "/fr/library/tome/rpg-1?page=1"
    assert_select ".collection-pages a:not([rel])[href=?]", "/fr/library/tome/rpg-1?page=1", "Page 1"
  end

  test "a set of more than sixty cards is paged" do
    season = seed_card_seasons(distinct_scores(130), publishers: Array.new(130, "Big"))
    assert Catalog::PublishSeason.new.call(number: season.number).success?
    members = set_members(season.reload, "big")

    get library_set_path(locale: :en, kind: "publisher", key: "big")
    assert_equal members.first(60).map { title(it) }, slots.map(&:second)
    assert_select ".collection-pages a[rel=next][href=?]", "/en/library/publisher/big?page=2"

    get library_set_path(locale: :en, kind: "publisher", key: "big", page: 3)
    assert_equal members.last(10).map { title(it) }, slots.map(&:second)
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

  test "a player's request costs sixteen queries, a visitor's ten" do
    season = publish_sets_draft
    player = accounts_players(:player)
    hold(player, set_members(season, "action-1").first, 1)
    sign_in(player)

    # Player lookup, published season; the grid: the set, its genres, count,
    # page, card views, the player's slots; the list: count, page, totals,
    # progress; the figures: unique cards, the season's cards, copies per
    # tier; the tab bar's trades waiting.
    assert_request_queries(16) { get library_set_path(locale: :en, kind: "tome", key: "action-1") }
    assert_response :success

    delete session_path(locale: :en)
    # The same without the lookup, the slots, the progress, the unique cards
    # and the copies per tier.
    assert_request_queries(10) { get library_set_path(locale: :en, kind: "tome", key: "action-1") }
    assert_response :success
  end
end
