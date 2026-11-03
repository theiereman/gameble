require "application_system_test_case"
require_relative "../support/catalog_seeds"
require_relative "../support/game_sets"
require_relative "../support/steam_sign_in"

# The bottom sheet, through the card list's QUICK FILTERS on a 390 × 844
# phone: opened by a tap or the keyboard as a modal dialog named by its
# title, its focus kept inside, closed by a drag on its grip, its ✕, the
# scrim or Escape with the focus back on its link; a choice reloads the list
# with that filter. On a desktop the same sheet opens centred; under reduced
# motion it only crossfades.
class BottomSheetTest < ApplicationSystemTestCase
  include CatalogSeeds
  include GameSets
  include SteamSignIn

  PHONE = [ 390, 844 ].freeze
  OPENER = "a.quick-filters__opener"
  SHEET = "dialog#quick-filters"

  setup do
    publish_sets_draft
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
    assert_focused "#{SHEET} .bottom-sheet__body a.filter-chip"
    assert_equal "Every card", evaluate_script("document.activeElement.textContent").strip
    eventually("a screen reader should meet a dialog named Quick filters") { dialogs_in_accessibility_tree.map(&:downcase) == [ "quick filters" ] }
    width, height = viewport
    eventually("the sheet should sit full width on the bottom edge") { sheet_box.values_at(0, 2, 3) == [ 0, width, height ] }
    assert evaluate_script("document.elementFromPoint(10, 10) === document.querySelector('#{SHEET}')"), "a tap above the sheet should land on its scrim"
    assert evaluate_script("(() => { const search = document.querySelector('#collection-search'); search.focus(); return document.activeElement !== search })()"),
      "the page behind the sheet should take no focus"
    within(SHEET) do
      assert_equal [ nil, "STATE", "RARITY" ], all(".quick-filters > *").map { it.first(".quick-filters__legend", minimum: 0)&.text }
      assert all("a.filter-chip").all? { it.evaluate_script("this.getBoundingClientRect().height") >= 44 }, "every choice should be a 44px target"
    end
  end

  test "the keyboard opens the sheet with Enter, keeps Tab inside it, and Escape gives the focus back to the link" do
    resize_to(*PHONE)
    sign_in
    visit_cards

    find(OPENER).send_keys(:enter)

    assert_open
    assert_focused "#{SHEET} .bottom-sheet__body a.filter-chip"
    execute_script("Array.from(document.querySelectorAll('#{SHEET} a.filter-chip')).at(-1).focus()")
    page.send_keys(:tab)
    assert_focused "#{SHEET} button.modal__close"
    page.send_keys([ :shift, :tab ])
    assert_focused "#{SHEET} li:last-child > a.filter-chip"
    assert_equal "Legendary", evaluate_script("document.activeElement.textContent").strip

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

  test "a choice reloads the card list with that filter alone, marked current the next time" do
    resize_to(*PHONE)
    sign_in
    visit_cards

    find(OPENER).click
    assert_open
    within(SHEET) { click_on "Missing" }

    assert_current_path library_cards_path(locale: :en, state: %w[missing])
    assert_selector "input[name='state[]'][value=missing]:checked", visible: :all
    assert_closed
    find(OPENER).click
    assert_open
    within(SHEET) do
      assert_selector "a.filter-chip[aria-current=true]", count: 1, text: "MISSING"
      assert_selector "a.filter-chip:not([aria-current])", text: "EVERY CARD"
    end
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

  test "a visitor's sheet offers every card and the rarities alone" do
    resize_to(*PHONE)
    visit_cards

    find(OPENER).click

    assert_open
    within(SHEET) do
      assert_equal [ nil, "RARITY" ], all(".quick-filters > *").map { it.first(".quick-filters__legend", minimum: 0)&.text }
      assert_selector "a.filter-chip[aria-current=true]", text: "EVERY CARD"
    end
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
