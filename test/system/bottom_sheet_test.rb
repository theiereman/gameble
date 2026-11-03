require "application_system_test_case"
require_relative "../support/catalog_seeds"
require_relative "../support/game_sets"
require_relative "../support/steam_sign_in"

# The bottom sheet, through the card list's Rarity pastille on a 390 × 844
# phone: opened by a tap or the keyboard as a modal dialog named by its
# title, its focus kept inside, closed by a drag on its grip, its ✕, the
# scrim or Escape with the focus back on its pastille. On a desktop the same
# sheet opens centred; under reduced motion it only crossfades.
class BottomSheetTest < ApplicationSystemTestCase
  include CatalogSeeds
  include GameSets
  include SteamSignIn

  PHONE = [ 390, 844 ].freeze
  OPENER = "a.filter-row__pastille[href='#filters-rarity']"
  SHEET = "dialog#filters-rarity"
  RARITIES = %w[COMMON UNCOMMON RARE EPIC LEGENDARY].freeze

  setup do
    @season = publish_sets_draft
    @player = accounts_players(:player)
    mock_steam_sign_in(@player.steam_id)
  end

  teardown do
    page.driver.browser.execute_cdp("Emulation.setEmulatedMedia", features: [ { name: "prefers-reduced-motion", value: "" } ])
  end

  def sign_in
    visit home_path(locale: :en)
    click_steam_sign_in
    assert_signed_in
  end

  def visit_cards
    visit library_cards_path(locale: :en)
    assert_selector OPENER
  end

  # Open, a modal dialog, done rising.
  def assert_open
    assert_selector SHEET, visible: true
    eventually("the sheet should be a modal dialog") { evaluate_script("document.querySelector('#{SHEET}').matches(':modal')") }
    eventually("the sheet should be done rising") { evaluate_script("document.querySelector('#{SHEET}').getAnimations({ subtree: true }).length === 0") }
  end

  def assert_closed
    assert_no_selector SHEET, visible: true
  end

  def assert_focused(selector)
    page.document.synchronize(Capybara.default_max_wait_time) do
      focused = evaluate_script("document.activeElement?.outerHTML.slice(0, 120)")
      raise Capybara::ExpectationNotMet, "focus on #{focused}, not #{selector}" unless evaluate_script("document.activeElement?.matches(#{selector.to_json})")
    end
  end

  def sheet_box = evaluate_script("(() => { const r = document.querySelector('#{SHEET}').getBoundingClientRect(); return [ r.left, r.top, r.right, r.bottom ].map(Math.round) })()")

  def viewport = evaluate_script("[ document.documentElement.clientWidth, window.innerHeight ]")

  def sheet_style(property) = evaluate_script("getComputedStyle(document.querySelector('#{SHEET}')).#{property}")

  # The names of the dialogs the accessibility tree exposes, as a screen
  # reader reads them.
  def dialogs_in_accessibility_tree
    browser = page.driver.browser
    browser.execute_cdp("Accessibility.enable")
    browser.execute_cdp("Accessibility.getFullAXTree")["nodes"]
      .select { !it["ignored"] && it.dig("role", "value") == "dialog" }
      .map { it.dig("name", "value") }
  end

  # A finger on the sheet's grip, as touch pointer events: it goes down,
  # moves `dy` px, and lifts unless `lift` is false.
  def drag_grip(dy, lift: true)
    execute_script(<<~JS, dy, lift)
      const [ dy, lift ] = arguments
      const grip = document.querySelector("#{SHEET} .bottom-sheet__grip")
      const box = grip.getBoundingClientRect()
      const x = box.left + box.width / 2, y = box.top + box.height / 2
      const event = (type, clientY) => new PointerEvent(type, { bubbles: true, pointerId: 7, pointerType: "touch", isPrimary: true, clientX: x, clientY })
      grip.dispatchEvent(event("pointerdown", y))
      grip.dispatchEvent(event("pointermove", y + dy / 2))
      grip.dispatchEvent(event("pointermove", y + dy))
      if (lift) grip.dispatchEvent(event("pointerup", y + dy))
    JS
  end

  def lift_grip(dy)
    execute_script(<<~JS, dy)
      const grip = document.querySelector("#{SHEET} .bottom-sheet__grip")
      const box = grip.getBoundingClientRect()
      grip.dispatchEvent(new PointerEvent("pointerup", { bubbles: true, pointerId: 7, pointerType: "touch", isPrimary: true, clientX: box.left, clientY: box.top + arguments[0] }))
    JS
  end

  test "a tap opens the sheet at the bottom edge as a modal dialog named by its title, the page behind inert, focus on its first choice" do
    resize_to(*PHONE)
    sign_in
    visit_cards
    assert_closed

    find(OPENER).click

    assert_open
    assert_focused "#{SHEET} .bottom-sheet__body input.filter-chip__box[value=common]"
    eventually("a screen reader should meet a dialog named Rarity") { dialogs_in_accessibility_tree.map(&:downcase) == [ "rarity" ] }
    width, height = viewport
    eventually("the sheet should sit full width on the bottom edge") { sheet_box.values_at(0, 2, 3) == [ 0, width, height ] }
    assert evaluate_script("document.elementFromPoint(10, 10) === document.querySelector('#{SHEET}')"), "a tap above the sheet should land on its scrim"
    assert evaluate_script("(() => { const search = document.querySelector('#collection-search'); search.focus(); return document.activeElement !== search })()"),
      "the page behind the sheet should take no focus"
    within(SHEET) do
      assert_equal RARITIES, all(".filter-chip__text").map(&:text)
      assert all(".filter-chip__text").all? { it.evaluate_script("this.getBoundingClientRect().height") >= 44 }, "every choice should be a 44px target"
    end
  end

  test "the keyboard opens the sheet with Enter, keeps Tab inside it, and Escape gives the focus back to the link" do
    resize_to(*PHONE)
    sign_in
    visit_cards

    find(OPENER).send_keys(:enter)

    assert_open
    assert_focused "#{SHEET} .bottom-sheet__body input.filter-chip__box[value=common]"
    execute_script("Array.from(document.querySelectorAll('#{SHEET} input.filter-chip__box')).at(-1).focus()")
    page.send_keys(:tab)
    assert_focused "#{SHEET} button.modal__close"
    page.send_keys([ :shift, :tab ])
    assert_focused "#{SHEET} input.filter-chip__box[value=legendary]"

    page.send_keys(:escape)

    assert_closed
    assert_focused OPENER
  end

  test "a drag down the grip closes the sheet, a short one springs back; the ✕ and the scrim close it too" do
    resize_to(*PHONE)
    sign_in
    visit_cards

    find(OPENER).click
    assert_open
    resting = sheet_box
    drag_grip(30, lift: false)
    assert_equal "30px", evaluate_script("document.querySelector('#{SHEET}').style.getPropertyValue('--sheet-drag')")
    eventually("the sheet should follow the finger") { sheet_box[1] == resting[1] + 30 }
    lift_grip(30)
    assert_open
    eventually("the sheet should spring back") { sheet_box == resting }
    assert_nil find(SHEET)["data-dragging"]

    drag_grip(200)
    assert_closed
    assert_focused OPENER

    find(OPENER).click
    assert_open
    within(SHEET) { find("button.modal__close[aria-label=Close]").click }
    assert_closed
    assert_focused OPENER

    find(OPENER).click
    assert_open
    page.driver.browser.action.move_to_location(195, 20).click.perform
    assert_closed
    assert_focused OPENER
  end

  test "a chip ticked in the sheet reloads the grid behind it, its pastille and the sheet's status following" do
    resize_to(*PHONE)
    sign_in
    visit_cards
    rare = Catalog::CardSeason.where(season_id: @season.id, rarity: "rare").count

    find(OPENER).click
    assert_open
    within(SHEET) { find(".filter-chip__text", text: /\ARare\z/i).click }

    assert_selector "#{SHEET} p.filter-sheet__status[role=status]", text: "#{rare} cards shown."
    assert_selector ".collection-grid > li:nth-child(#{[ rare, 60 ].min})", visible: :all
    assert_no_selector ".collection-grid > li:nth-child(#{[ rare, 60 ].min + 1})", visible: :all
    assert_open
    assert_selector "#{SHEET} input[value=rare]:checked", visible: :all
    assert_selector "#{OPENER} .filter-row__count", text: "1", visible: :all
    assert_selector ".filters__clear:not([hidden])", visible: :all
    assert_current_path(/rarity%5B%5D=rare|rarity\[\]=rare/)
    page.send_keys(:escape)
    assert_closed
    assert_selector "#{OPENER} .filter-row__count", text: "1"
    assert_selector ".filters__clear", visible: true
  end

  test "a page cached with a sheet the player opened comes back by history with no sheet open" do
    resize_to(*PHONE)
    sign_in
    visit_cards
    find(".tab-bar a.tab-bar__tab", text: /SETS/i).click
    assert_current_path library_path(locale: :en)
    click_on "All cards"
    assert_current_path library_cards_path(locale: :en)

    find(OPENER).click
    assert_open
    within(SHEET) { find(".filter-chip__text", text: /\ARare\z/i).click }
    assert_selector "#{OPENER} .filter-row__count", text: "1", visible: :all
    assert_open
    page.send_keys(:escape)
    assert_closed

    page.go_back
    assert_current_path library_path(locale: :en)
    page.go_back
    assert_current_path library_cards_path(locale: :en)
    assert_selector ".collection-grid > li", minimum: 1
    assert_no_selector "dialog.bottom-sheet[open]", visible: :all
    eventually("no sheet should be a modal dialog") { evaluate_script("document.querySelectorAll('dialog.bottom-sheet:modal').length") == 0 }
  end

  test "on a desktop the same sheet opens centred" do
    sign_in
    visit_cards

    find(OPENER).click

    assert_open
    width, height = viewport
    eventually("the sheet should stand in the middle of the window") do
      left, top, right, bottom = sheet_box
      ((left + right) / 2 - width / 2).abs <= 1 && ((top + bottom) / 2 - height / 2).abs <= 1
    end
  end

  test "a visitor's row offers Rarity and More alone" do
    resize_to(*PHONE)
    visit_cards

    assert_equal %w[RARITY MORE], all("a.filter-row__pastille").map { it.text.strip }
    find(OPENER).click

    assert_open
    within(SHEET) { assert_equal RARITIES, all(".filter-chip__text").map(&:text) }
  end

  test "under reduced motion the sheet only crossfades, opening and springing back" do
    resize_to(*PHONE)
    sign_in
    visit_cards
    find(OPENER).click
    assert_open
    assert_equal [ "modal-sheet", "0.18s" ], [ sheet_style("animationName"), sheet_style("transitionDuration") ]
    find("#{SHEET} button.modal__close").click
    assert_closed

    page.driver.browser.execute_cdp("Emulation.setEmulatedMedia", features: [ { name: "prefers-reduced-motion", value: "reduce" } ])
    find(OPENER).click

    assert_open
    assert_equal [ "modal-fade", "0s" ], [ sheet_style("animationName"), sheet_style("transitionDuration") ]
  end
end
