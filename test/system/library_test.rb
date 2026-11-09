require "application_system_test_case"
require_relative "../support/catalog_seeds"
require_relative "../support/game_packs"
require_relative "../support/game_sets"
require_relative "../support/steam_sign_in"

# The collection: EN COURS loads more of a kind and a set search finds any
# set; the grid of every card narrows from its filter row and search without
# losing focus, appends its pages, moves its focus by arrow keys and comes
# back from a card on its appended cards; the cards of a pack just opened
# are new until a grid has shown them.
class LibraryTest < ApplicationSystemTestCase
  include CatalogSeeds
  include GamePacks
  include GameSets
  include SteamSignIn

  setup do
    @season = publish_sets_draft
    @player = accounts_players(:player)
    @theme = members("horror")
    @theme.first(3).each_with_index do |card_season_id, index|
      Game::Holding.create!(player_id: @player.id, card_season_id:, quantity: index == 1 ? 2 : 1)
    end
    mock_steam_sign_in(@player.steam_id)
  end

  def members(key)
    set = Catalog::Set.find_by!(season_id: @season.id, key:)
    Catalog::SetMembership.where(set_id: set.id).order(:position, :id).pluck(:card_season_id)
  end

  def sign_in
    visit home_path(locale: :en)
    click_steam_sign_in
    assert_signed_in
    visit home_path(locale: :en)
  end

  def tile(key) = find(".set-tiles a.set-tile[href='#{library_set_path(locale: :en, kind: "theme", key:)}']")

  def iris(tile, property) = tile.evaluate_script("getComputedStyle(this).getPropertyValue('--iris-#{property}').trim()")

  # More sets in progress than a page holds: themes of three cards, two held.
  def start_more_sets(count)
    cards = Catalog::CardSeason.where(season_id: @season.id).order(:id).ids.last(count * 3)
    count.times do |index|
      members = cards.slice(index * 3, 3)
      insert_theme(members, key: "extra-#{index}", season: @season)
      hold_all(@player, members.first(2))
    end
  end

  test "EN COURS shows six sets of a kind, Load more adds the next ones, and the search finds any set as tiles in place of the lists, under OBJECTIFS" do
    start_more_sets(8)
    assert_equal 12, Game::SetBoard.call(@player, season: @season).in_progress.size
    sign_in
    visit library_path(locale: :en)

    assert_selector "#set-entry-theme-title ~ .set-tiles a.set-tile", count: 6
    find("#set-entry-theme-title ~ turbo-frame.set-more a.button", text: /load more/i).click
    assert_selector ".set-tiles a.set-tile", count: 12
    assert_no_selector "turbo-frame.set-more a.button"
    assert_selector ".set-tiles a.set-tile:focus"

    fill_in "set-search-field", with: "rpg"
    assert_selector "#set-results-title", text: /\ARESULTS\z/
    assert_selector ".set-results .set-tiles a.set-tile[href='#{library_set_path(locale: :en, kind: "theme", key: "rpg")}']"
    assert_selector ".set-results .set-chip--none", text: /NO TIER/i
    assert_no_selector "#set-entry-in-progress-title"
    assert_selector ".set-entry > #goals:first-child ~ .set-search"

    fill_in "set-search-field", with: ""
    assert_no_selector "#set-results-title"
    assert_selector "#set-entry-in-progress .set-tiles a.set-tile", count: 12
  end

  test "the filter row: a chip ticked in a sheet narrows the grid behind it, each pastille counting its own, a search narrows as it is typed" do
    sign_in
    visit library_cards_path(locale: :en)
    assert_slots 60
    assert_no_selector ".filter-row__count", visible: true

    open_filter_sheet(:state)
    within(filter_sheet(:state)) { find(".filter-chip__text", text: /\AOwned\z/i).click }
    assert_slots 3
    assert_selector "#{filter_sheet(:state)} p.filter-sheet__status", text: "3 cards shown."
    assert_selector "#{pastille(:state)} .filter-row__count", text: "1", visible: :all
    within(filter_sheet(:state)) { find(".filter-chip__text", text: /\AMissing\z/i).click }
    assert_slots 60
    assert_selector ".collection-slot__copies", count: 3, visible: :all
    assert_selector "#{pastille(:state)} .filter-row__count", text: "2", visible: :all
    within(filter_sheet(:state)) { find(".filter-chip__text", text: /\AOwned\z/i).click }
    assert_selector ".collection-grid .card--not-owned", count: 57, visible: :all
    assert_selector "#{pastille(:state)} .filter-row__count", text: "1", visible: :all

    # Back to the owned cards, then a rarity, then a genre none of them has.
    within(filter_sheet(:state)) do
      find(".filter-chip__text", text: /\AOwned\z/i).click
      find(".filter-chip__text", text: /\AMissing\z/i).click
    end
    assert_slots 3
    close_filter_sheet(:state)
    assert_selector "#{pastille(:state)} .filter-row__count", text: "1"
    assert_selector ".filters__clear", visible: true

    held = Catalog::CardSeason.where(id: @theme.first(3)).pluck(:rarity)
    open_filter_sheet(:rarity)
    within(filter_sheet(:rarity)) { find(".filter-chip__text", text: /\A#{held.first}\z/i).click }
    assert_slots held.count(held.first)
    close_filter_sheet(:rarity)
    assert_selector "#{pastille(:rarity)} .filter-row__count", text: "1"
    assert_selector "#{pastille(:state)} .filter-row__count", text: "1"

    open_filter_sheet(:more)
    within("#{filter_sheet(:more)} [data-group=genre]") { find(".filter-chip__text", text: /\ARPG\z/i).click }
    assert_selector ".collection-grid__empty", text: "Nothing matches these filters.", visible: :all
    assert_equal "RPG", page.evaluate_script("document.activeElement.parentElement.textContent.trim()")
    assert_selector "#{filter_sheet(:more)} p.filter-sheet__status", text: "No card shown."
    assert_selector "#{pastille(:more)} .filter-row__count", text: "1", visible: :all
    close_filter_sheet(:more)

    # The search narrows as it is typed, and keeps the focus in the field.
    find(".filters__clear").click
    assert_slots 60
    assert_no_selector ".filter-row__count", visible: true
    title = Catalog::CardSeason.find(@theme.first).card.texts.find_by!(locale: "en").title
    field = find("#collection-search")
    field.click
    field.send_keys(title)
    assert_selector ".collection-grid .card__title", text: title.upcase
    assert_selector "#collection-search:focus"
    field.send_keys("zzzz")
    assert_selector ".collection-grid__empty"
    assert_selector "#collection-search:focus"
  end

  test "the cards of a pack just opened are new; once the grid has shown them, the next visit shows them no longer" do
    create_pack(@player, cards: @theme[3, 5], available_at: 1.year.ago, season: @season)
    sign_in
    assert Game::OpenPack.new.call(player: @player).success?

    visit library_set_path(locale: :en, kind: "theme", key: "horror")

    assert_selector ".collection-slot__new", count: 5, text: "NEW"
    assert_equal @theme[3, 5].map { Catalog::CardSeason.find(it).card.texts.find_by!(locale: "en").title.upcase },
      all(".collection-slot:has(.collection-slot__new) .card__title").map(&:text)

    visit library_cards_path(locale: :en, state: [ "new" ])

    assert_selector ".collection-slot__new", count: 5, text: "NEW"
    gained = Game::Holding.where(player_id: @player.id, card_season_id: @theme[3, 5]).maximum(:last_gained_at)
    assert_equal gained, wait_for_watermark

    visit library_set_path(locale: :en, kind: "theme", key: "horror")

    assert_selector ".collection-grid .card.card--grid:not(.card--not-owned)", count: 8
    assert_no_selector ".collection-slot__new"
  end

  test "a player's filtered, searched grid appends its next page as its links come near, the status naming the cards shown" do
    held = Catalog::CardSeason.where(season_id: @season.id, main_theme: "roguelike").order(:number, :id).last(2)
    held.each { Game::Holding.create!(player_id: @player.id, card_season_id: it.id, quantity: 1) }
    held_paths = held.map { "/en/cards/#{it.card.slug}/" }
    sign_in
    filters = { state: %w[missing], genre: %w[roguelike], q: "seed" }
    visit library_cards_path(locale: :en, **filters, page: 2)
    second_page = all(".collection-grid a.card-link", minimum: 1).map { it[:href] }
    assert_equal 21, second_page.size

    visit library_cards_path(locale: :en, **filters)
    assert_slots 60
    scroll_to_pages

    assert_slots 81
    appended = all(".collection-grid > li:nth-child(n+61) a.card-link", visible: :all).map { it[:href] }
    assert_equal second_page, appended
    assert_selector ".collection-grid > li:nth-child(n+61) .card.card--not-owned", count: 21, visible: :all
    assert_no_selector ".collection-grid .collection-slot__copies", visible: :all
    assert appended.none? { |href| held_paths.any? { URI(href).path.start_with?(it) } }
    assert_selector "#collection-results-status", text: "Cards 61 to 81 of 81 shown.", visible: :all
    assert_no_selector "#collection-pages a[rel=next]", visible: :all
    assert_selector "#collection-pages a[rel=prev][href*='state%5B%5D=missing']", visible: :all
    assert_selector "#collection-pages [aria-current=page]", text: "2", visible: :all
    assert_current_path library_cards_path(locale: :en, **filters)
  end

  test "the grid is one tab stop: arrow keys move the focus by card and by row, into appended pages, End reaches the last card" do
    visit library_cards_path(locale: :en)
    assert_slots 60
    assert_selector ".collection-grid a.card-link[tabindex='0']", count: 1, visible: :all
    columns = evaluate_script("[...document.querySelectorAll('.collection-grid > li')].filter((slot, _, slots) => slot.getBoundingClientRect().top === slots[0].getBoundingClientRect().top).length")

    find(".collection-grid > li:first-child a.card-link").execute_script("this.focus()")
    page.send_keys(:right)
    assert_focused ".collection-grid > li:nth-child(2) a.card-link"
    page.send_keys(:down)
    assert_focused ".collection-grid > li:nth-child(#{2 + columns}) a.card-link"

    scroll_to_pages
    assert_slots 120
    assert_no_selector ".collection-grid a.card-link:not([tabindex])", visible: :all
    assert_selector ".collection-grid a.card-link[tabindex='0']", count: 1, visible: :all
    find(".collection-grid > li:nth-child(60) a.card-link").execute_script("this.focus()")
    page.send_keys(:down)
    assert_focused ".collection-grid > li:nth-child(#{60 + columns}) a.card-link"
    page.send_keys(:end)
    assert_focused ".collection-grid > li:nth-child(120) a.card-link"
    page.send_keys(:tab)
    eventually("the focus stayed in the grid") { evaluate_script("!document.activeElement?.closest('.collection-grid')") }
  end

  test "back from a card of an appended page, the grid shows its appended cards, the focus on that card's link" do
    visit library_cards_path(locale: :en)
    scroll_to_pages
    assert_slots 120

    find(".collection-grid > li:nth-child(61) a.card-link").click
    assert_selector ".card-detail h1"
    assert_no_selector "html[aria-busy]", visible: :all

    go_back

    assert_current_path library_cards_path(locale: :en)
    assert_selector ".collection-grid > li:nth-child(120)", visible: :all
    assert_focused ".collection-grid > li:nth-child(61) a.card-link"
  end

  private
    # A count assertion over the grid reads every slot it found, one round
    # trip each, to check its visibility or to word a failed attempt's
    # message: over a hundred slots one attempt outlasts the wait, before
    # the page appended or the frame reloaded lands. The last slot and the
    # absence of the next one each read one node at most.
    def assert_slots(count)
      assert_selector ".collection-grid > li:nth-child(#{count})", visible: :all
      assert_no_selector ".collection-grid > li:nth-child(#{count + 1})", visible: :all
    end

    def pastille(group) = "a.filter-row__pastille[href='#filters-#{group}']"

    def filter_sheet(group) = "dialog#filters-#{group}"

    def open_filter_sheet(group)
      find(pastille(group)).click
      assert_selector filter_sheet(group), visible: true
      eventually("the #{group} sheet should be a modal dialog") { evaluate_script("document.querySelector('#{filter_sheet(group)}').matches(':modal')") }
    end

    def close_filter_sheet(group)
      within(filter_sheet(group)) { find("button.modal__close").click }
      assert_no_selector filter_sheet(group), visible: true
    end

    def scroll_to_pages
      find("#collection-pages").execute_script("this.scrollIntoView({ block: 'end' })")
    end

    def assert_focused(selector)
      eventually("the focus is not on #{selector}") { evaluate_script("document.activeElement?.matches(#{selector.to_json})") }
    end

    # The watermark the page posted, waited for (the POST runs after the
    # page has rendered).
    def wait_for_watermark
      page.document.synchronize do
        Game::PlayerState.find_by!(player_id: @player.id).collection_seen_up_to || raise(Capybara::ElementNotFound, "the watermark is not posted yet")
      end
    end
end
