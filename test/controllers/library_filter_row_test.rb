require "test_helper"
require_relative "../support/catalog_seeds"
require_relative "../support/game_sets"
require_relative "../support/library_requests"
require_relative "../support/steam_sign_in"

class LibraryFilterRowTest < ActionDispatch::IntegrationTest
  include CatalogSeeds
  include GameSets
  include LibraryRequests
  include SteamSignIn

  setup do
    @season = publish_sets_draft
    @player = accounts_players(:player)
  end

  def add_goal(kind:, key:) = Game::AddGoal.new.call(player: @player, kind:, key:).value!

  def cards_path(**filter) = library_cards_path(locale: :en, **filter)

  def sheet(pastille) = "form.filters > dialog#filters-#{pastille}.modal.bottom-sheet[aria-labelledby=filters-#{pastille}-title]"

  # Each pastille as [ its name, its count or nil when none is on ].
  def pastilles
    css_select("form.filters > ul.filter-row > li > a.filter-chip.filter-row__pastille").map do |pastille|
      count = pastille.at_css(".filter-row__count")
      [ pastille.at_css(".filter-chip__text").children.first.text.strip, (count.at_css("[data-pastille-number]").text.to_i unless count.key?("hidden")) ]
    end
  end

  def groups_in(pastille) = css_select("#{sheet(pastille)} fieldset.filters__group").map { it["data-group"] }

  test "a player with a goal gets the search, then Goals, Rarity, State and More, each opening its sheet of chips in the form" do
    add_goal(kind: "theme", key: "horror")
    sign_in(@player)

    get cards_path

    assert_response :success
    assert_select "form.filters > .filters__search:first-child > #collection-search"
    assert_select "form.filters > .filters__search + ul.filter-row"
    assert_equal [ [ "Goals", nil ], [ "Rarity", nil ], [ "State", nil ], [ "More", nil ] ], pastilles
    assert_select "details.filters__zone, .filters__summary, .quick-filters, #quick-filters", false
    %w[goals rarity state more].each do |pastille|
      assert_select "a.filter-row__pastille[href='#filters-#{pastille}'][aria-haspopup=dialog][aria-controls=filters-#{pastille}][data-bottom-sheet-opens=filters-#{pastille}]"
      assert_select sheet(pastille)
    end
    assert_equal [ "Goals", "Rarity", "State", "More filters" ], css_select("form.filters > dialog .modal__title").map(&:text)
    assert_equal [ %w[goals], %w[rarity], %w[state], %w[sets genre] ], %w[goals rarity state more].map { groups_in(it) }
    assert_equal [ "Goals", "Rarity", "State" ], css_select("form.filters > dialog legend.filters__legend.visually-hidden").map(&:text)
    assert_select "#{sheet(:more)} turbo-frame#collection-set-options"
    assert_equal [ "150 cards shown." ] * 4, css_select("form.filters > dialog p.filter-sheet__status[role=status][data-collection-filters-target=sheetStatus]").map(&:text)
    assert_equal [ "rarity", "state", "goals", "sets genre" ].sort, css_select("[data-collection-filters-target=pastilleCount]").map { it["data-groups"] }.sort
    assert_select "form.filters > a.filters__clear[hidden]"
    assert_select "form.filters > noscript"
    assert_select "[style]", false
  end

  test "a player without goals has no Goals pastille; a visitor has Rarity and More alone" do
    sign_in(@player)
    get cards_path
    assert_equal [ "Rarity", "State", "More" ], pastilles.map(&:first)
    assert_select "dialog#filters-goals", false

    delete session_path(locale: :en)
    get cards_path
    assert_equal [ [ "Rarity", nil ], [ "More", nil ] ], pastilles
    assert_select "dialog#filters-state, [data-group=state]", false
  end

  test "arriving filtered, each pastille counts its own chips on and its sheet holds them ticked" do
    add_goal(kind: "theme", key: "horror")
    sign_in(@player)

    get cards_path(rarity: %w[rare], state: %w[missing])
    assert_equal [ [ "Goals", nil ], [ "Rarity", 1 ], [ "State", 1 ], [ "More", nil ] ], pastilles
    assert_equal [ "rare" ], css_select("#{sheet(:rarity)} input[name='rarity[]'][checked]").map { it["value"] }
    assert_equal [ "missing" ], css_select("#{sheet(:state)} input[name='state[]'][checked]").map { it["value"] }
    assert_select "form.filters > a.filters__clear:not([hidden])[href=?]", "/en/library/cards"
    assert_select "a.filter-row__pastille[href='#filters-rarity'] .filter-row__count", "Active filters: 1"

    get cards_path(sets: %w[theme:horror theme:rpg], genre: %w[rpg], goals: %w[theme:horror], state: %w[all])
    assert_equal [ [ "Goals", 1 ], [ "Rarity", nil ], [ "State", nil ], [ "More", 3 ] ], pastilles
  end

  test "a public profile's collection and a player's set album keep their folded FILTRES zone, without the row" do
    get brother_collection_path(locale: :en, token: @player.token)
    assert_response :success
    assert_select "form.filters details.filters__zone .filters__groups > fieldset[data-group=rarity]"
    assert_select "ul.filter-row, dialog.bottom-sheet", false

    sign_in(@player)
    get library_set_path(locale: :en, kind: "theme", key: "horror")
    assert_response :success
    assert_select "form.filters details.filters__zone"
    assert_select "ul.filter-row, dialog.bottom-sheet", false
  end

  test "the row costs the card list no query" do
    add_goal(kind: "theme", key: "horror")
    sign_in(@player)

    assert_request_queries(25) { get cards_path }
    assert_select "#{sheet(:goals)} .filter-chip--goal", 1

    delete session_path(locale: :en)
    assert_request_queries(9) { get cards_path }
    assert_select "#{sheet(:rarity)} .filter-chip", Catalog::Rarity::TIERS.size
  end
end
