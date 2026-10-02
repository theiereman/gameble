require "application_system_test_case"

# The card, as the server draws it and as the React Card draws it
# (back-office card preview, administrators only).
class CardPreviewTest < ApplicationSystemTestCase
  PAIRS = Catalog::Rarity::TIERS.values.product(%w[face back], %w[small large]).map { |parts| parts.join("-") } +
    (0..4).map { |level| "sapphire-back-small-dust-#{level}" }

  # A card's markup reduced to what both renderers must share: tag, sorted
  # classes, role, aria-*, `use href` and its own text, collapsed; data-*,
  # style, size and hidden are left out.
  PROJECTION = <<~JS.freeze
    (pair, renderer) => {
      const project = (node) => {
        const attributes = {}
        for (const { name, value } of node.attributes) {
          if (name === "role" || name.startsWith("aria-") || (node.localName === "use" && name === "href")) attributes[name] = value
        }
        const text = [...node.childNodes].filter((child) => child.nodeType === Node.TEXT_NODE)
          .map((child) => child.textContent).join("").replace(/\\s+/g, " ").trim()
        return { tag: node.localName, classes: [...node.classList].sort(), attributes, text, children: [...node.children].map(project) }
      }
      const card = document.querySelector(`[data-pair="${pair}"][data-renderer="${renderer}"] > .card`)
      return card ? JSON.stringify(project(card)) : null
    }
  JS

  setup do
    OmniAuth.config.test_mode = true
    administrator = accounts_players(:administrator)
    OmniAuth.config.mock_auth[:steam] = OmniAuth::AuthHash.new(provider: "steam", uid: "https://steamcommunity.com/openid/id/#{administrator.steam_id}")
    visit home_path(locale: :en)
    click_on "Enlist through Steam"
    assert_button "Stand down"
  end

  teardown do
    OmniAuth.config.mock_auth.delete(:steam)
    OmniAuth.config.test_mode = false
  end

  def projection(pair, renderer)
    page.evaluate_script("(#{PROJECTION})(#{pair.to_json}, #{renderer.to_json})")
  end

  def visit_preview
    visit back_office_cards_path(locale: :en)
    assert_selector "[data-renderer=react] .card", count: PAIRS.size
    # The server's faces draw their art only near the viewport: each is
    # brought into view until it starts, then the page goes back to the top.
    page.all("[data-renderer=server] .card--face .card__art", visible: :all).each do |art|
      scroll_to(art, align: :center)
      art.assert_matches_selector("[data-art]", visible: :all)
    end
    page.execute_script("window.scrollTo(0, 0)")
    # Every face's art has settled, on both sides.
    assert_no_selector ".card--face .card__art:not([data-art])"
  end

  test "both renderers draw every pair with the same markup, and the sample art" do
    visit_preview

    assert_equal PAIRS, page.all("[data-renderer=server]").map { it["data-pair"] }
    PAIRS.each do |pair|
      server = projection(pair, "server")
      assert server, "no server card for #{pair}"
      assert_equal server, projection(pair, "react"), "the two renderers differ on #{pair}"
    end

    faces = page.all(".card--face .card__art", visible: :all)
    assert_equal 20, faces.size
    assert_equal 16, page.all(".card--face .card__art[data-art=drawn] canvas:not([hidden])", visible: :all).size
    # A drawn canvas holds the filtered art: opaque pixels at the art size.
    drawn = page.evaluate_script(<<~JS)
      [...document.querySelectorAll(".card--face .card__art[data-art=drawn] canvas")].every((canvas) => {
        const data = canvas.getContext("2d").getImageData(0, 0, canvas.width, canvas.height).data
        return (canvas.width === 68 || canvas.width === 104) && data[3] === 255 && data[data.length - 1] === 255
      })
    JS
    assert drawn, "every drawn canvas should hold the art"
    take_screenshot
  end

  test "a missing art hides the canvas and keeps the frame and title" do
    visit_preview

    %w[emerald-face-small emerald-face-large].each do |pair|
      %w[server react].each do |renderer|
        within("[data-pair=#{pair}][data-renderer=#{renderer}]") do
          assert_selector ".card__art[data-art=failed]"
          assert_selector ".card__canvas", visible: :hidden
          assert_selector ".card__frame", visible: :all
          assert_selector ".card__title", text: "Green Hills"
        end
      end
    end
  end

  test "a long title shows two lines and keeps its full text" do
    visit_preview

    title = page.find("[data-pair=amethyst-face-small][data-renderer=server] .card__title")
    assert_equal "The Long Chronicles of the Amethyst Archive and the Keys Its Keepers Lost at Sea", title.text(:all)
    line = page.evaluate_script("parseFloat(getComputedStyle(document.querySelector('[data-pair=amethyst-face-small] .card__title')).lineHeight)")
    assert_equal 2 * line, title.evaluate_script("this.getBoundingClientRect().height")

    plates = page.evaluate_script("[...document.querySelectorAll('.card__plate')].map((plate) => plate.getBoundingClientRect().height)")
    assert plates.all? { |height| height.to_i == height && height.to_i.even? }, "plate heights should be even: #{plates.uniq}"
  end

  test "the legendary face sweeps and blinks; with reduced motion the sweep stops and the sparkles stay" do
    visit_preview
    sweep = "[data-pair=gold-face-large][data-renderer=server] .card__sweep"
    sparkle = "[data-pair=gold-face-large][data-renderer=server] .card__sparkle"
    style = ->(selector, property) { page.evaluate_script("getComputedStyle(document.querySelector(#{selector.to_json}))[#{property.to_json}]") }

    assert_equal "card-sweep", style.(sweep, "animationName")
    assert_equal "card-sparkle", style.(sparkle, "animationName")

    page.driver.browser.execute_cdp("Emulation.setEmulatedMedia", features: [ { name: "prefers-reduced-motion", value: "reduce" } ])
    assert_equal "none", style.(sweep, "animationName")
    assert_equal "none", style.(sparkle, "animationName")
    assert_equal "1", style.(sparkle, "opacity")
    assert_equal 7, page.all("[data-pair=gold-face-large][data-renderer=react] .card__sparkle", visible: :all).size
  ensure
    page.driver.browser.execute_cdp("Emulation.setEmulatedMedia", features: [ { name: "prefers-reduced-motion", value: "" } ])
  end

  test "a Turbo restore visit draws the art again" do
    visit_preview
    art = "[data-pair=steel-face-small][data-renderer=server] .card__art"
    # A stale mark and a hidden canvas, as the snapshot Turbo caches on leaving.
    page.execute_script("const art = document.querySelector(#{art.to_json}); art.dataset.art = 'stale'; art.querySelector('canvas').hidden = true")
    click_on "Back to the attic"
    assert_selector ".attic"

    page.go_back
    assert_selector "#{art}[data-art=drawn] canvas:not([hidden])"
    painted = page.evaluate_script(<<~JS)
      (() => {
        const canvas = document.querySelector("[data-pair=steel-face-small][data-renderer=server] canvas")
        return canvas.getContext("2d").getImageData(0, 0, 1, 1).data[3]
      })()
    JS
    assert_equal 255, painted
  end
end
