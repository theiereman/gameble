require "application_system_test_case"
require_relative "../support/game_packs"

# The shell in a real browser (story 8.1): the top bar, the phone tab bar
# under 720px only, no sideways scroll, toasts that close, the two fonts
# loaded (Space Mono for every small text, VT323 for the large text only,
# never under 20px, nothing under 10px), on a desktop and on the two
# reference phones; screenshots of the hub, the library, a card, a pack and
# the back-office.
class ShellTest < ApplicationSystemTestCase
  include GamePacks

  PHONES = { "390" => [ 390, 844 ], "360" => [ 360, 740 ] }.freeze
  FONTS = [ '16px "Space Mono"', '700 16px "Space Mono"', '16px "VT323"' ].freeze
  FAMILIES = [ "Space Mono", "VT323" ].freeze

  setup do
    OmniAuth.config.test_mode = true
  end

  teardown do
    OmniAuth.config.mock_auth.delete(:steam)
    OmniAuth.config.test_mode = false
  end

  def sign_in(player, locale: :en)
    OmniAuth.config.mock_auth[:steam] = OmniAuth::AuthHash.new(provider: "steam", uid: "https://steamcommunity.com/openid/id/#{player.steam_id}")
    visit home_path(locale:)
    find(".top-bar .steam-sign-in__button").click
    assert_selector ".top-bar .player-chip"
  end

  def assert_no_sideways_scroll
    assert page.evaluate_script("document.documentElement.scrollWidth <= window.innerWidth"), "the page should not scroll sideways"
  end

  def assert_fonts_loaded
    loaded = page.evaluate_async_script(<<~JS, FONTS)
      const [fonts, done] = arguments
      Promise.all(fonts.map((font) => document.fonts.load(font))).then(() => done(fonts.map((font) => document.fonts.check(font))))
    JS
    assert_equal [ true ] * FONTS.size, loaded, "Space Mono and VT323 should be loaded"
  end

  # The faces the page declares: the two families, none of the old pixel fonts.
  def assert_font_set
    families = page.evaluate_script(<<~JS)
      Array.from(new Set(Array.from(document.fonts, (face) => face.family.replace(/^"|"$/g, "")))).sort()
    JS
    assert_equal FAMILIES, families, "document.fonts should hold Space Mono and VT323 only"
  end

  # Every element with text of its own sits at 10px or more, and at 20px or
  # more when it is set in VT323; a failure names the offending selectors.
  def assert_text_sizes
    offenders = page.evaluate_script(<<~JS)
      Array.from(document.body.querySelectorAll("*"))
        .filter((element) => Array.from(element.childNodes).some((node) => node.nodeType === Node.TEXT_NODE && node.textContent.trim() !== ""))
        .flatMap((element) => {
          const style = getComputedStyle(element)
          const size = parseFloat(style.fontSize)
          const floor = /^"?VT323"?/.test(style.fontFamily) ? 20 : 10
          if (size >= floor) return []
          const selector = element.tagName.toLowerCase() + Array.from(element.classList, (name) => `.${name}`).join("")
          return [`${selector}: ${size}px in ${style.fontFamily}, floor ${floor}px`]
        })
    JS
    assert_empty offenders, "every text should sit at its floor:\n#{offenders.join("\n")}"
  end

  def computed(selector, property)
    page.evaluate_script("getComputedStyle(document.querySelector(#{selector.to_json})).#{property}")
  end

  test "on a desktop: the top bar, no tab bar, the dark ground, the two fonts and their size floors" do
    player = accounts_players(:player)
    3.times { create_pack(player) }
    create_pack(player, available_at: 5.minutes.from_now)
    sign_in(player)

    assert_selector ".top-bar .rarity-counter__button", visible: true
    assert_selector ".top-bar a.packs-chip[href='/en/booster']", text: /3\s+BOOSTERS/i
    assert_selector ".packs-chip__next", text: /\+1 in \d\d:\d\d/i, visible: true
    assert_no_selector ".tab-bar", visible: true
    assert_equal "rgb(11, 15, 21)", computed("body", "backgroundColor")
    assert_match(/Space Mono/, computed("body", "fontFamily"))
    assert_fonts_loaded
    assert_font_set
    assert_text_sizes
    assert_no_sideways_scroll
    take_screenshot

    find(".rarity-counter__button").click
    assert_selector "#rarity-legend", visible: true, text: /RARITIES/i
    find(".rarity-counter__button").send_keys(:escape)
    assert_no_selector "#rarity-legend", visible: true

    find(".player-chip__button").click
    within("#player-menu") { assert_link "My public profile" }
    take_screenshot
  end

  PHONES.each do |name, size|
    test "on a #{name} px phone: the tab bar fixed at the bottom, no rarity counter, no sideways scroll" do
      resize_to(*size)
      sign_in(accounts_players(:player), locale: :fr)

      assert_selector ".tab-bar", visible: true
      assert_selector ".tab-bar a.tab-bar__tab[aria-current=page]", text: /PONT/i
      assert_selector ".tab-bar a.tab-bar__tab[href='/fr/booster']", text: /BOOSTER/i
      assert_selector ".tab-bar a.tab-bar__tab[href='/fr/more']", text: /PLUS/i
      assert_selector ".tab-bar span.tab-bar__tab[aria-disabled=true]", count: 1
      assert_no_selector ".rarity-counter__button", visible: true
      assert_selector ".top-bar .player-chip__button", visible: true
      assert_equal "fixed", computed(".tab-bar", "position")
      bottom = page.evaluate_script("Math.round(document.querySelector('.tab-bar').getBoundingClientRect().bottom)")
      assert_equal page.evaluate_script("window.innerHeight"), bottom
      assert_no_sideways_scroll
      assert_fonts_loaded
      take_screenshot

      visit library_path(locale: :fr)
      assert_selector ".tab-bar a.tab-bar__tab[aria-current=page]", text: /COLLECTION/i
      assert_no_sideways_scroll
      take_screenshot
    end
  end

  test "a toast closes with its button, and a gameble:toast event adds one" do
    visit back_office_path(locale: :en)

    assert_selector ".toasts .toast.toast--alert", text: I18n.t("authorization.sign_in_required", locale: :en)
    find(".toast .toast__close").click
    assert_no_selector ".toasts .toast"

    page.execute_script(<<~JS)
      window.dispatchEvent(new CustomEvent("gameble:toast", { detail: { title: "Proposition envoyée", message: "Léa a 7 jours pour répondre." } }))
    JS
    assert_selector ".toasts .toast.toast--notice .toast__title", text: /PROPOSITION ENVOYÉE/i
    assert_selector ".toasts .toast .toast__message", text: "Léa a 7 jours pour répondre."
    take_screenshot
    find(".toast__close[aria-label=Close]").click
    assert_no_selector ".toasts .toast"
  end

  test "a toast goes by itself once its time is up" do
    visit home_path(locale: :en)
    page.execute_script(<<~JS)
      window.dispatchEvent(new CustomEvent("gameble:toast", { detail: { message: "Gone soon." } }))
    JS

    assert_selector ".toasts .toast", text: "Gone soon."
    assert_no_selector ".toasts .toast", wait: 9
  end

  test "a hovered toast waits, ignores unknown fields, and goes once the pointer leaves" do
    visit home_path(locale: :en)
    page.execute_script(<<~JS)
      window.dispatchEvent(new CustomEvent("gameble:toast", { detail: { message: "Stay a while.", colour: "pink" } }))
    JS

    toast = find(".toasts .toast", text: "Stay a while.")
    toast.hover
    # Past its six seconds, still there while the pointer rests on it.
    sleep 7
    assert_selector ".toasts .toast", text: "Stay a while."

    find(".top-bar").hover
    assert_no_selector ".toasts .toast", wait: 9
  end

  # Runs Turbo's refresh of the page shown (as the hub's countdown does) and
  # waits for it to finish.
  def refresh_with_turbo
    page.execute_script(<<~JS)
      delete document.documentElement.dataset.testLoaded
      document.addEventListener("turbo:load", () => { document.documentElement.dataset.testLoaded = "" }, { once: true })
      Turbo.visit(location.href, { action: "replace" })
    JS
    assert_selector "html[data-test-loaded]", visible: :all
  end

  # The star field is still: it carries no shift and does not move.
  def assert_stars_still
    assert_selector ".atmosphere__stars", visible: :all
    assert_no_selector ".atmosphere__stars[style*='--star-shift']", visible: :all
    assert_equal "none", computed(".atmosphere__stars", "transform")
  end

  test "a refresh of the same page is no screen change; a visit to another one is" do
    visit home_path(locale: :en)

    refresh_with_turbo
    assert_selector "html[data-screen-change=same]", visible: :all
    # The screen is not captured apart, so no old picture lingers under the new one.
    assert_equal "none", computed(".main", "viewTransitionName")

    within(".hub-menu") { click_on "Collection" }
    assert_current_path library_path(locale: :en)
    assert_no_selector "html[data-screen-change]", visible: :all
    assert_equal "screen", computed(".main", "viewTransitionName")

    # Another page than the hub, refreshed (a plain replace, no morph).
    refresh_with_turbo
    assert_selector "html[data-screen-change=same]", visible: :all
  end

  test "Back and Forward are screen changes: the screen slides and the stars stay" do
    visit home_path(locale: :en)
    within(".hub-menu") { click_on "Collection" }
    assert_current_path library_path(locale: :en)
    assert_stars_still
    refresh_with_turbo
    assert_selector "html[data-screen-change=same]", visible: :all
    assert_stars_still

    page.go_back
    assert_current_path home_path(locale: :en)
    assert_selector ".hub-menu"
    assert_no_selector "html[data-screen-change]", visible: :all
    assert_equal "screen", computed(".main", "viewTransitionName")
    assert_stars_still
  end

  test "a few stars twinkle softly, slowly, and stop under reduced motion, read live" do
    visit home_path(locale: :en)
    twinkles = "document.querySelector('.atmosphere__twinkle').getAnimations({ subtree: true }).filter((a) => a.playState === 'running')"

    assert_equal 12, evaluate_script("#{twinkles}.length")
    # A slow fade: every period is 3 s or more (below 1 Hz).
    assert evaluate_script("#{twinkles}.every((a) => a.effect.getTiming().duration >= 3000)")

    execute_script("document.documentElement.dataset.motion = 'reduced'")
    assert_equal 0, evaluate_script("#{twinkles}.length")
  end

  test "the back-office, without stars, leaves no same-page mark behind" do
    sign_in(accounts_players(:administrator))
    refresh_with_turbo
    assert_selector "html[data-screen-change=same]", visible: :all

    find(".top-bar .player-chip").click
    click_on "Back-office"
    assert_selector "body.is-back-office"
    assert_no_selector "html[data-screen-change]", visible: :all
    assert_equal "none", computed(".main", "viewTransitionName")

    find(".top-bar__start a").click
    assert_current_path home_path(locale: :en)
    assert_no_selector "body.is-back-office"
    assert_no_selector "html[data-screen-change]", visible: :all
    assert_equal "screen", computed(".main", "viewTransitionName")
  end

  test "the tab bar and the toasts are captured apart from the sliding screen" do
    resize_to(*PHONES["390"])
    visit home_path(locale: :en)
    assert_equal "tab-bar", computed(".tab-bar", "viewTransitionName")
    assert_equal "toasts", computed(".toasts", "viewTransitionName")
  end

  test "a toast stays through a morph refresh of the hub" do
    visit home_path(locale: :en)
    page.execute_script(<<~JS)
      window.dispatchEvent(new CustomEvent("gameble:toast", { detail: { message: "Still here after the refresh of the page, as long as its time is not up yet, which takes a while." } }))
    JS
    assert_selector ".toasts .toast", text: "Still here"

    refresh_with_turbo
    assert_selector ".toasts .toast", text: "Still here"
  end

  test "several toasts stay through a morph refresh of the hub, in their order" do
    visit home_path(locale: :en)
    page.execute_script(<<~JS)
      for (const message of ["First toast, kept through the refresh of the page for a while.", "Second toast, kept through the refresh of the page as well."]) {
        window.dispatchEvent(new CustomEvent("gameble:toast", { detail: { message } }))
      }
    JS
    assert_selector ".toasts .toast", count: 2

    refresh_with_turbo
    messages = all(".toasts .toast .toast__message").map(&:text)
    assert_equal 2, messages.size
    assert_match(/\AFirst toast/i, messages.first)
    assert_match(/\ASecond toast/i, messages.last)
    assert_no_selector ".toasts .toast", wait: 12
  end

  test "the daily bonus's notice joins the toasts kept through the hub's refresh, and all leave by themselves" do
    player = accounts_players(:player)
    Game::FillBank.new.call(player:).value!
    Game::OpenPack.new.call(player:).value!
    sign_in(player)
    find(".toasts .toast__close").click
    assert_no_selector ".toasts .toast"
    page.execute_script(<<~JS)
      for (const message of ["One toast already on screen.", "Another toast already on screen."]) {
        window.dispatchEvent(new CustomEvent("gameble:toast", { detail: { message } }))
      }
    JS
    assert_selector ".toasts .toast", count: 2

    within(".daily-booster") { click_on "Collect" }

    notice = I18n.t("daily_bonuses.create.collected", locale: :en)
    # The collect, its redirect and the hub's render: slower than Capybara's
    # 2 s when the parallel workers load the machine.
    assert_selector ".toasts .toast.toast--notice", text: notice, wait: 6
    assert_selector ".toasts .toast", count: 3
    assert_no_selector ".toasts .toast", wait: 12
  end

  test "the daily bonus's notice, brought by the hub's refresh, leaves by itself" do
    player = accounts_players(:player)
    Game::FillBank.new.call(player:).value!
    Game::OpenPack.new.call(player:).value!
    sign_in(player)

    within(".daily-booster") { click_on "Collect" }

    notice = I18n.t("daily_bonuses.create.collected", locale: :en)
    # The collect, its redirect and the hub's render: slower than Capybara's
    # 2 s when the parallel workers load the machine.
    assert_selector ".toasts .toast.toast--notice", text: notice, wait: 6
    assert_no_selector ".toasts .toast", text: notice, wait: 12
  end

  test "Esc closes the toast that holds the focus" do
    visit home_path(locale: :en)
    page.execute_script(<<~JS)
      window.dispatchEvent(new CustomEvent("gameble:toast", { detail: { message: "Press Esc to close me." } }))
    JS

    find(".toast__close").send_keys(:escape)
    assert_no_selector ".toasts .toast"
  end

  test "on a phone the toasts sit at the top" do
    resize_to(*PHONES["390"])
    visit back_office_path(locale: :en)

    assert_selector ".toasts .toast"
    assert_operator page.evaluate_script("document.querySelector('.toasts').getBoundingClientRect().top"), :<, 40
    take_screenshot
  end

  test "the screens inside the shell: hub, library, a card, a pack, the back-office" do
    player = accounts_players(:administrator)
    pack = create_pack(player, cards: fixture_tier_ids, opened_at: Time.current)
    sign_in(player)
    take_screenshot

    { library: library_path(locale: :en), card: card_path(locale: :en, slug: "portal"),
      pack: pack_path(locale: :en, token: pack.token), back_office: back_office_path(locale: :en) }.each do |name, path|
      visit path
      assert_selector ".top-bar__start .button__label", text: /BRIDGE/i
      assert_equal "rgb(11, 15, 21)", computed("body", "backgroundColor"), name
      assert_no_sideways_scroll
      take_screenshot
    end
    assert_selector "body.is-back-office"
    assert_no_selector "#atmosphere", visible: :all

    resize_to(*PHONES["360"])
    visit card_path(locale: :en, slug: "portal")
    assert_no_sideways_scroll
    take_screenshot
  end
end
