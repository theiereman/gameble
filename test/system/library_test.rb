require "application_system_test_case"
require_relative "../support/catalog_seeds"
require_relative "../support/game_packs"

# The collection (CAP-6, story 10.1): a player reaches it from the hub's
# menu 02 or the phone's COLLECTION tab, picks a set and sees its progress,
# their faces with their copies and the missing cards named, on a desktop
# and a 390 × 844 phone without sideways scroll; the cards of a pack just
# opened are new, and no longer once seen; a visitor sees every slot
# missing. Story 10.7: it opens on the owned cards, and the FILTRES zone and
# the search narrow the grid without losing focus.
class LibraryTest < ApplicationSystemTestCase
  include CatalogSeeds
  include GamePacks

  setup do
    @season = publish_sets_draft
    @player = accounts_players(:player)
    @tome = members("action-1")
    @tome.first(3).each_with_index do |card_season_id, index|
      Game::Holding.create!(player_id: @player.id, card_season_id:, quantity: index == 1 ? 2 : 1)
    end
    OmniAuth.config.test_mode = true
    OmniAuth.config.mock_auth[:steam] = OmniAuth::AuthHash.new(provider: "steam", uid: "https://steamcommunity.com/openid/id/#{@player.steam_id}")
  end

  teardown do
    OmniAuth.config.mock_auth.delete(:steam)
    OmniAuth.config.test_mode = false
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

  def row(name) = find(".collection-sets .set-row", text: /\A#{Regexp.escape(name)}\b/i)

  test "a player goes from menu 02 to a tome: its progress, their faces with their copies, the missing cards named" do
    sign_in

    within(".hub-menu") { click_on "Collection" }

    assert_current_path library_path(locale: :en)
    assert_selector ".top-bar__title", text: /\ACOLLECTION\z/
    assert_selector ".collection-status", text: %r{\AUnique cards:\s*3 / 150}
    assert_selector ".collection-sets .set-row[aria-current=page]", text: /WHOLE SEASON/
    assert_selector ".report--panel", visible: true
    assert_selector ".collection-grid > li", count: 3
    take_screenshot

    row("Action · Tome 1").click

    assert_current_path library_set_path(locale: :en, kind: "tome", key: "action-1")
    assert_selector ".collection-sets .set-row[aria-current=page]", text: /ACTION · TOME 1\s*3\/25/
    assert_selector ".collection-sets .set-row", text: %r{ACTION · TOME 2\s*0/25}
    assert_selector ".collection-grid > li", count: 3
    find(".filters__summary").click
    find(".filter-chip__text", text: /\AAll\z/i).click
    assert_selector ".collection-grid > li", count: 25
    assert_selector ".collection-grid .card.card--m", count: 3
    assert_selector ".collection-slot__copies", count: 3
    assert_selector ".collection-slot__copies", text: "x2", count: 1
    assert_selector ".missing-slot", count: 22
    missing = Catalog::CardSeason.find(@tome[3])
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

    click_on "Bridge"
    assert_current_path home_path(locale: :en)
  end

  # The grid's sixty slots are counted with `visible: :all`, in one call:
  # checking each one's visibility is sixty round trips to the browser, and
  # on a loaded runner one such attempt outlasts the wait while the frame
  # the filter reloads replaces the nodes under it.
  test "a visitor who unticks the only state chip keeps every slot, as the form without JavaScript" do
    visit library_path(locale: :en)
    find(".filters__summary").click
    assert_selector ".collection-grid > li", count: 60, visible: :all
    find(".filter-chip__text", text: /\AAll\z/i).click
    assert_selector ".collection-grid > li", count: 60, visible: :all
    assert_equal [ "ALL" ], all("[data-group=state] .filter-chip__box:checked", visible: :all).map { it.find(:xpath, "..").text.strip }
    assert_selector ".filters__count", visible: :hidden
    assert_selector "[role=status]", text: "150 cards shown.", visible: :all
  end

  test "on a 390 × 844 phone the tab leads here: the sets a strip of chips, the RAPPORT folded, two cards a row" do
    page.driver.browser.manage.window.resize_to(390, 844)
    sign_in

    find(".tab-bar a.tab-bar__tab", text: /COLLECTION/i).click

    assert_current_path library_path(locale: :en)
    assert_selector ".collection-grid > li", count: 3
    assert_no_selector ".report--panel", visible: true
    assert_no_selector ".collection-status__label", visible: true
    assert_selector ".collection-status__value", text: "3 / 150"
    chip = page.evaluate_script("(() => { const r = document.querySelector('.collection-sets__list .set-row').getBoundingClientRect(); return [ r.width, r.height >= 48 ] })()")
    assert_equal [ 132, true ], chip
    tops = page.evaluate_script("[...document.querySelectorAll('.collection-grid > li')].slice(0, 3).map((slot) => Math.round(slot.getBoundingClientRect().top))")
    assert_equal tops[0], tops[1]
    assert_operator tops[2], :>, tops[0]
    assert_no_sideways_scroll

    find(".report--fold summary").click
    assert_selector ".report--fold[open] .report__row", text: /UNIQUE CARDS\s*3/
    take_screenshot

    row("Action · Tome 1").click
    assert_selector ".collection-sets .set-row[aria-current=page]", text: %r{3/25}
    assert_selector ".collection-grid .card.card--m", count: 3
    assert_no_sideways_scroll
    take_screenshot
  end

  test "the FILTRES zone: chips narrow the grid, the zone keeps focus, the count follows, a search narrows as it is typed" do
    sign_in
    visit library_path(locale: :en)
    assert_selector ".collection-grid > li", count: 3
    assert_no_selector ".filters__zone[open]"
    assert_no_selector ".filters__count", visible: true

    find(".filters__summary").click
    find(".filter-chip__text", text: /\AMissing\z/i).click
    assert_selector ".collection-grid > li", count: 60, visible: :all
    assert_selector ".collection-slot .card", count: 3
    assert_selector ".filters__count", text: "2"
    find(".filter-chip__text", text: /\AOwned\z/i).click
    assert_selector ".collection-grid .missing-slot", count: 60, visible: :all
    assert_no_selector ".collection-slot .card"
    assert_selector ".filters__count", text: "1"
    assert_selector ".filters__clear", visible: true

    # Back to the owned cards, then a genre none of them has.
    find(".filter-chip__text", text: /\AOwned\z/i).click
    find(".filter-chip__text", text: /\AMissing\z/i).click
    assert_selector ".collection-grid > li", count: 3
    assert_no_selector ".filters__count", visible: true
    within("[data-group=genre]") do
      find(".filter-chip__text", text: /\ARPG\z/i).click
    end
    assert_selector ".collection-grid__empty", text: "Nothing matches these filters."
    assert_equal "RPG", page.evaluate_script("document.activeElement.parentElement.textContent.trim()")
    assert_selector ".filters__count", text: "1"

    # The search narrows as it is typed, and keeps the focus in the field.
    find(".filters__clear").click
    assert_selector ".collection-grid > li", count: 3
    title = Catalog::CardSeason.find(@tome.first).card.texts.find_by!(locale: "en").title
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

  test "the cards of a pack just opened are new; once seen, the next visit shows them no longer" do
    create_pack(@player, cards: @tome[3, 5], available_at: 1.year.ago)
    sign_in
    assert Game::OpenPack.new.call(player: @player).success?

    visit library_set_path(locale: :en, kind: "tome", key: "action-1")

    assert_selector ".collection-slot__new", count: 5, text: "NEW"
    assert_equal @tome[3, 5].map { Catalog::CardSeason.find(it).card.texts.find_by!(locale: "en").title.upcase },
      all(".collection-slot:has(.collection-slot__new) .card__title").map(&:text)
    take_screenshot
    gained = Game::Holding.where(player_id: @player.id, card_season_id: @tome[3, 5]).maximum(:last_gained_at)
    assert_equal gained, wait_for_watermark

    visit library_set_path(locale: :en, kind: "tome", key: "action-1")

    assert_selector ".collection-grid .card.card--m", count: 8
    assert_no_selector ".collection-slot__new"
  end

  test "a visitor reaches the collection from the hub's menu by keyboard and sees every slot missing" do
    visit home_path(locale: :fr)

    find(".hub-menu a.menu-item[aria-keyshortcuts='2']").send_keys(:enter)

    assert_current_path library_path(locale: :fr)
    assert_selector ".collection-status", text: "0 / 150"
    assert_selector ".missing-slot", count: 60, visible: :all
    assert_no_selector ".collection-grid .card, .collection-slot__new"
    assert_selector ".top-bar .steam-sign-in__button"
    assert_no_sideways_scroll
  end

  test "on a 360 × 740 phone a visitor keeps the Steam image, and two cards still fit a row" do
    page.driver.browser.manage.window.resize_to(360, 740)

    visit library_path(locale: :en)

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
      deadline = Time.current + Capybara.default_max_wait_time
      loop do
        seen = Game::PlayerState.find_by!(player_id: @player.id).collection_seen_up_to
        return seen if seen || Time.current > deadline

        sleep 0.1
      end
    end
end
