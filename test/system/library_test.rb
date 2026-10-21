require "application_system_test_case"
require_relative "../support/catalog_seeds"
require_relative "../support/game_packs"
require_relative "../support/steam_sign_in"

# The collection: a player reaches its entry from the hub's menu 02 or the
# phone's COLLECTION tab, picks a set and sees its progress, their faces with
# their copies and the missing cards named, on a desktop and a 390 × 844 phone
# without sideways scroll; the grid of every card, with its FILTRES zone and
# search, narrows without losing focus; the cards of a pack just opened are
# new until a grid has shown them; a visitor reads the grid in plain faces.
class LibraryTest < ApplicationSystemTestCase
  include CatalogSeeds
  include GamePacks
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
  end

  def assert_no_sideways_scroll
    assert page.evaluate_script("document.documentElement.scrollWidth <= window.innerWidth"), "the page should not scroll sideways"
  end

  def row(name) = find(".set-entry__list .set-row", text: /\A#{Regexp.escape(name)}\b/i)

  test "a player goes from menu 02 to a theme: its progress, their faces with their copies, the missing cards named" do
    sign_in

    within(".hub-menu") { click_on "Collection" }

    assert_current_path library_path(locale: :en)
    assert_selector ".top-bar__title", text: /\ACOLLECTION\z/
    assert_selector ".collection-status", text: %r{\AUnique cards:\s*3 / 150}
    assert_selector ".set-entry__list .set-row", text: %r{HORROR\s+THEME\s+3/16}
    assert_selector ".set-entry__list .set-row", text: %r{PIRATES\s+THEME\s+3/8}
    assert_no_selector ".collection-grid"
    take_screenshot

    row("Horror").click

    assert_current_path library_set_path(locale: :en, kind: "theme", key: "horror")
    assert_selector ".set-album__count", text: "3/16"
    assert_selector ".collection-grid > li", count: 16
    assert_selector ".collection-grid .card.card--grid", count: 3
    assert_selector ".collection-slot__copies", text: "x2", count: 1
    assert_selector ".missing-slot", count: 13
    missing = Catalog::CardSeason.find(@theme[3])
    within(all(".collection-grid > li")[3]) do
      assert_selector ".missing-slot__title", text: missing.card.texts.find_by!(locale: "en").title.upcase
      assert_selector ".missing-slot__year", text: missing.card.release_date.year.to_s
    end
    # The badges sit at the card's corners, inside the slot's painted box.
    corner = page.evaluate_script(<<~JS)
      (() => {
        const slot = document.querySelector(".collection-slot .collection-slot__copies").closest("li")
        const card = slot.querySelector(".card").getBoundingClientRect()
        const badge = slot.querySelector(".collection-slot__copies").getBoundingClientRect()
        const box = slot.getBoundingClientRect()
        return [ Math.round(badge.right - card.right), Math.round(card.top - badge.top), badge.right <= box.right, badge.top >= box.top ]
      })()
    JS
    assert_equal [ 6, 6, true, true ], corner
    assert_no_sideways_scroll
    take_screenshot

    find(".top-bar__home").click
    assert_current_path home_path(locale: :en)
  end


  # The grid's sixty slots are counted with `visible: :all`, in one call:
  # checking each one's visibility is sixty round trips to the browser, and
  # on a loaded runner one such attempt outlasts the wait while the frame
  # the filter reloads replaces the nodes under it.
  test "a player who unticks the only state chip keeps every slot, as the form without JavaScript" do
    sign_in
    visit library_cards_path(locale: :en)
    find(".filters__summary").click
    assert_selector ".collection-grid > li", count: 60, visible: :all
    find(".filter-chip__text", text: /\AAll\z/i).click
    assert_selector ".collection-grid > li", count: 60, visible: :all
    assert_equal [ "ALL" ], all("[data-group=state] .filter-chip__box:checked", visible: :all).map { it.find(:xpath, "..").text.strip }
    assert_selector ".filters__count", visible: :hidden
    assert_selector "[role=status]", text: "150 cards shown.", visible: :all
  end

  test "on a 390 × 844 phone the tab leads here: the sets a list of rows, then the grid with the RAPPORT folded, two cards a row" do
    page.driver.browser.manage.window.resize_to(390, 844)
    sign_in

    find(".tab-bar a.tab-bar__tab", text: /COLLECTION/i).click

    assert_current_path library_path(locale: :en)
    assert_selector ".collection-status__value", text: "3 / 150"
    assert_selector ".set-entry__list .set-row", text: %r{HORROR\s+THEME\s+3/16}
    assert_no_sideways_scroll

    click_on "All cards"

    assert_current_path library_cards_path(locale: :en)
    assert_selector ".collection-grid > li", count: 60, visible: :all
    assert_no_selector ".report--panel", visible: true
    assert_no_selector ".collection-status__label", visible: true
    assert_selector ".collection-status__value", text: "3 / 150"
    tops = page.evaluate_script("[...document.querySelectorAll('.collection-grid > li')].slice(0, 3).map((slot) => Math.round(slot.getBoundingClientRect().top))")
    assert_equal tops[0], tops[1]
    assert_operator tops[2], :>, tops[0]
    assert_no_sideways_scroll

    find(".report--fold summary").click
    assert_selector ".report--fold[open] .report__row", text: /UNIQUE CARDS\s*3/
    take_screenshot

    visit library_set_path(locale: :en, kind: "theme", key: "horror")
    assert_selector ".set-album__count", text: "3/16"
    assert_selector ".collection-grid .card.card--grid", count: 3
    assert_no_sideways_scroll
    take_screenshot
  end

  test "the FILTRES zone: chips narrow the grid, the zone keeps focus, the count follows, a search narrows as it is typed" do
    sign_in
    visit library_cards_path(locale: :en)
    assert_selector ".collection-grid > li", count: 60, visible: :all
    assert_no_selector ".filters__zone[open]"
    assert_no_selector ".filters__count", visible: true

    find(".filters__summary").click
    find(".filter-chip__text", text: /\AOwned\z/i).click
    assert_selector ".collection-grid > li", count: 3
    assert_selector ".filters__count", text: "1"
    assert_selector ".filters__clear", visible: true
    find(".filter-chip__text", text: /\AMissing\z/i).click
    assert_selector ".collection-grid > li", count: 60, visible: :all
    assert_selector ".collection-slot__copies", count: 3
    assert_selector ".filters__count", text: "2"
    find(".filter-chip__text", text: /\AOwned\z/i).click
    assert_selector ".collection-grid .card--not-owned", count: 57, visible: :all
    assert_no_selector ".collection-slot__copies"
    assert_selector ".filters__count", text: "1"

    # Back to the owned cards, then a genre none of them has.
    find(".filter-chip__text", text: /\AOwned\z/i).click
    find(".filter-chip__text", text: /\AMissing\z/i).click
    assert_selector ".collection-grid > li", count: 3
    assert_selector ".filters__count", text: "1"
    within("[data-group=genre]") do
      find(".filter-chip__text", text: /\ARPG\z/i).click
    end
    assert_selector ".collection-grid__empty", text: "Nothing matches these filters."
    assert_equal "RPG", page.evaluate_script("document.activeElement.parentElement.textContent.trim()")
    assert_selector ".filters__count", text: "2"

    # The search narrows as it is typed, and keeps the focus in the field.
    find(".filters__clear").click
    assert_selector ".collection-grid > li", count: 60, visible: :all
    assert_no_selector ".filters__count", visible: true
    title = Catalog::CardSeason.find(@theme.first).card.texts.find_by!(locale: "en").title
    field = find("#collection-search")
    field.click
    field.send_keys(title)
    assert_selector ".collection-grid .card__title", text: title.upcase
    assert_equal "collection-search", page.evaluate_script("document.activeElement.id")
    field.send_keys("zzzz")
    assert_selector ".collection-grid__empty"
    assert_equal "collection-search", page.evaluate_script("document.activeElement.id")
    assert_no_sideways_scroll
    take_screenshot
  end

  test "the cards of a pack just opened are new; once the grid has shown them, the next visit shows them no longer" do
    create_pack(@player, cards: @theme[3, 5], available_at: 1.year.ago, season: @season)
    sign_in
    assert Game::OpenPack.new.call(player: @player).success?

    visit library_set_path(locale: :en, kind: "theme", key: "horror")

    assert_selector ".collection-slot__new", count: 5, text: "NEW"
    assert_equal @theme[3, 5].map { Catalog::CardSeason.find(it).card.texts.find_by!(locale: "en").title.upcase },
      all(".collection-slot:has(.collection-slot__new) .card__title").map(&:text)
    take_screenshot

    visit library_cards_path(locale: :en, state: [ "new" ])

    assert_selector ".collection-slot__new", count: 5, text: "NEW"
    gained = Game::Holding.where(player_id: @player.id, card_season_id: @theme[3, 5]).maximum(:last_gained_at)
    assert_equal gained, wait_for_watermark

    visit library_set_path(locale: :en, kind: "theme", key: "horror")

    assert_selector ".collection-grid .card.card--grid", count: 8
    assert_no_selector ".collection-slot__new"
  end

  test "a visitor reads the grid of every card in plain faces, with no ownership data" do
    visit library_cards_path(locale: :fr)

    assert_selector ".collection-grid > li", count: 60, visible: :all
    assert_no_selector ".collection-status"
    assert_no_selector ".missing-slot, .collection-slot__new, .card--not-owned", visible: :all
    assert_no_selector ".report--panel", visible: :all
    assert_selector ".top-bar .steam-sign-in__button"
    assert_no_sideways_scroll
  end

  test "on a 360 × 740 phone a visitor keeps the Steam image, and two cards still fit a row" do
    page.driver.browser.manage.window.resize_to(360, 740)

    visit library_cards_path(locale: :en)

    assert_selector ".top-bar .steam-sign-in__button", visible: true
    assert_no_selector ".collection-status", visible: true
    tops = page.evaluate_script("[...document.querySelectorAll('.collection-grid > li')].slice(0, 3).map((slot) => Math.round(slot.getBoundingClientRect().top))")
    assert_equal tops[0], tops[1]
    assert_no_sideways_scroll
    take_screenshot
  end

  private
    # The watermark the page posted, waited for (the POST runs after the
    # page has rendered).
    def wait_for_watermark
      page.document.synchronize do
        Game::PlayerState.find_by!(player_id: @player.id).collection_seen_up_to || raise(Capybara::ElementNotFound, "the watermark is not posted yet")
      end
    end
end
