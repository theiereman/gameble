require "test_helper"
require_relative "../support/catalog_seeds"
require_relative "../support/game_sets"
require_relative "../support/library_requests"
require_relative "../support/steam_sign_in"

# The card list's QUICK FILTERS: a link beside the search opens a bottom
# sheet of one-tap filters, each a link to the list with that filter alone,
# the one in force marked current. A visitor has no state or goal to pick;
# a public profile's collection has no menu.
class LibraryQuickFiltersTest < ActionDispatch::IntegrationTest
  include CatalogSeeds
  include GameSets
  include LibraryRequests
  include SteamSignIn

  setup do
    @season = publish_sets_draft
    @player = accounts_players(:player)
  end

  def add_goal(kind:, key:) = Game::AddGoal.new.call(player: @player, kind:, key:).value!

  def sheet = "dialog#quick-filters.modal.bottom-sheet[aria-labelledby=quick-filters-title]"

  # The sheet's groups as [ legend, [ [ chip, href, current ] ] ], the
  # leading every-card group under a nil legend.
  def groups
    css_select("#{sheet} .quick-filters > *").map do |group|
      legend = group.at_css(".quick-filters__legend")&.text
      chips = group.css("a.filter-chip").map { [ it.at_css(".filter-chip__text").text, it["href"], it["aria-current"] == "true" ] }
      [ legend, chips ]
    end
  end

  def chips_of(legend) = groups.to_h.fetch(legend)

  def cards_path(**filter) = library_cards_path(locale: :en, **filter)

  test "a player's sheet offers every card, their goals, the states but all and the rarities, the filter in force marked" do
    add_goal(kind: "theme", key: "horror")
    add_goal(kind: "theme", key: "pirates")
    sign_in(@player)

    get cards_path(state: %w[missing])

    assert_response :success
    assert_select ".filters__search.filters__search--menu > #collection-search + a.filter-chip.quick-filters__opener[href='#quick-filters']" \
      "[aria-haspopup=dialog][aria-controls=quick-filters][data-bottom-sheet-opens=quick-filters]", text: "Quick filters"
    assert_select "#{sheet} #quick-filters-title", "Quick filters"
    assert_select "#{sheet} button.modal__close[aria-label=Close]"
    assert_select "form.filters #{sheet}", false

    assert_equal [ nil, "Goals", "State", "Rarity" ], groups.map(&:first)
    assert_equal [ [ "Every card", cards_path, false ] ], chips_of(nil)
    assert_equal [ [ "Owned", cards_path(state: %w[owned]), false ], [ "Missing", cards_path(state: %w[missing]), true ],
      [ "New", cards_path(state: %w[new]), false ], [ "Duplicates", cards_path(state: %w[duplicates]), false ] ], chips_of("State")
    assert_equal [ [ "Horror", cards_path(goals: %w[theme:horror]), false ], [ "Pirates", cards_path(goals: %w[theme:pirates]), false ] ],
      chips_of("Goals").map { [ it[0].delete("0-9"), *it[1..] ] }
    assert_equal [ "Goal 1: Horror", "Goal 2: Pirates" ], css_select("#{sheet} a.filter-chip--goal").map { it["aria-label"] }
    assert_equal Catalog::Rarity::TIERS.values.map { [ I18n.t("catalog.rarity.#{it}", locale: :en), cards_path(rarity: [ it.to_s ]), false ] }, chips_of("Rarity")
    assert css_select("#{sheet} a.filter-chip").all? { it["data-turbo-frame"] == "_top" }
    assert_select "[style]", false

    get cards_path(rarity: %w[rare], q: "")
    assert_equal [ "Rare" ], css_select("#{sheet} a.filter-chip[aria-current=true]").map(&:text)

    get cards_path
    assert_equal [ "Every card" ], css_select("#{sheet} a.filter-chip[aria-current=true]").map(&:text)

    get cards_path(rarity: %w[rare], state: %w[missing])
    assert_select "#{sheet} a.filter-chip[aria-current]", false

    get cards_path(goals: %w[theme:pirates])
    assert_equal [ "Goal 2: Pirates" ], css_select("#{sheet} a.filter-chip[aria-current=true]").map { it["aria-label"] }
  end

  test "a visitor's sheet offers every card and the rarities alone" do
    get cards_path

    assert_response :success
    assert_select "a.quick-filters__opener[href='#quick-filters']"
    assert_equal [ nil, "Rarity" ], groups.map(&:first)
    assert_equal [ [ "Every card", cards_path, true ] ], chips_of(nil)
  end

  test "a public profile's collection and a player's set album have no quick filters" do
    get brother_collection_path(locale: :en, token: @player.token)
    assert_response :success
    assert_select "form.filters"
    assert_select ".quick-filters__opener, dialog.bottom-sheet, .filters__search--menu", false

    sign_in(@player)
    get library_set_path(locale: :en, kind: "theme", key: "horror")
    assert_response :success
    assert_select "form.filters"
    assert_select ".quick-filters__opener, dialog.bottom-sheet", false
  end

  test "the sheet costs the card list no query" do
    add_goal(kind: "theme", key: "horror")
    sign_in(@player)

    # The card list's twenty-two queries with a goal, as before the sheet:
    # it reads the goals and the filters the page already holds.
    assert_request_queries(22) { get cards_path }
    assert_select "#{sheet} a.filter-chip--goal", 1

    delete session_path(locale: :en)
    assert_request_queries(8) { get cards_path }
    assert_select "#{sheet} a.filter-chip", 1 + Catalog::Rarity::TIERS.size
  end
end
