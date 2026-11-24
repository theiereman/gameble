require "application_system_test_case"
require_relative "../support/steam_sign_in"

# The card face as the server draws it (back-office card preview,
# administrators only): its art drawn on its canvas, the missing image, and
# the art drawn again after a Turbo restore; the card art through
# pixelcrush, filtered in the real card-art worker with 32 colours, in
# card-art elements added to the preview by script.
class CardPreviewTest < ApplicationSystemTestCase
  include SteamSignIn

  SIZES = { "s" => [ 112, 168, 50, 51 ], "m" => [ 160, 240, 72, 74 ], "l" => [ 208, 312, 94, 97 ], "xl" => [ 240, 360, 109, 112 ] }.freeze
  SPECIMENS = Catalog::Rarity::TIERS.values.product(SIZES.keys).map { |parts| parts.join("-") } +
    Catalog::Rarity::TIERS.values.map { |rarity| "#{rarity}-m-booster" }
  SAMPLE_CARD = "[data-specimen=common-s] .card__art".freeze

  PINNED_TO_THE_TOP = "position: fixed; inset: 0 auto auto 0; z-index: 1000; display: flex; flex-wrap: wrap".freeze

  # Adds one card-art element per URL, at the small art size, pinned to the
  # top of the window so each nears the viewport at once, unless the host is
  # placed otherwise.
  ADD_ARTS = <<~JS.freeze
    (urls, hostStyle) => {
      const host = document.createElement("div")
      host.style.cssText = hostStyle
      urls.forEach((url, index) => {
        const art = document.createElement("span")
        art.style.display = "inline-block"
        art.dataset.testArt = index
        art.dataset.controller = "card-art"
        art.dataset.cardArtUrlValue = url
        art.dataset.cardArtWidthValue = 68
        art.dataset.cardArtHeightValue = 108
        const canvas = document.createElement("canvas")
        canvas.width = 68
        canvas.height = 108
        canvas.dataset.cardArtTarget = "canvas"
        art.append(canvas)
        host.append(art)
      })
      document.body.append(host)
    }
  JS

  setup do
    administrator = accounts_players(:administrator)
    sign_in_browser(administrator.steam_id)
  end

  teardown do
    reduce_motion(false)
  end

  def reduce_motion(on)
    page.driver.browser.execute_cdp("Emulation.setEmulatedMedia", features: [ { name: "prefers-reduced-motion", value: on ? "reduce" : "" } ])
  end

  def style(selector, property)
    page.evaluate_script("getComputedStyle(document.querySelector(#{selector.to_json}))[#{property.to_json}]")
  end

  def box(selector)
    page.evaluate_script("(() => { const r = document.querySelector(#{selector.to_json}).getBoundingClientRect(); return [ r.width, r.height ] })()")
  end

  def sample_path
    find(SAMPLE_CARD, visible: :all)["data-card-art-url-value"]
  end

  def add_arts(urls, host_style: PINNED_TO_THE_TOP)
    page.execute_script("(#{ADD_ARTS})(#{urls.to_json}, #{host_style.to_json})")
  end

  def visit_preview
    visit back_office_cards_path(locale: :en)
    assert_selector "[data-specimen] > .card", count: SPECIMENS.size
    # Faces draw their art only near the viewport: each is brought into view
    # until it starts, then the page goes back to the top.
    page.all("[data-specimen] .card__art", visible: :all).each do |art|
      scroll_to(art, align: :center)
      art.assert_matches_selector("[data-art]", visible: :all)
    end
    page.execute_script("window.scrollTo(0, 0)")
    assert_no_selector ".card__art:not([data-art])", visible: :all
  end

  test "every specimen with an art has it drawn on its canvas, a missing art shows the picture and its words in the face's frame, a Turbo restore visit draws the art again, from a clean face, and thirty covers are filtered in the worker, each in at most 32 colours" do
    visit_preview

    assert_equal SPECIMENS, page.all("[data-specimen]").map { it["data-specimen"] }

    drawn = page.all(".card__art[data-art=drawn] canvas:not([hidden])", visible: :all)
    # Every specimen but the uncommon's five, whose art is missing.
    assert_equal 20, drawn.size
    opaque = page.evaluate_script(<<~JS)
      [...document.querySelectorAll(".card__art[data-art=drawn] canvas")].every((canvas) => {
        const data = canvas.getContext("2d").getImageData(0, 0, canvas.width, canvas.height).data
        return data[3] === 255 && data[data.length - 1] === 255
      })
    JS
    assert opaque, "every drawn canvas should hold the art"

    SIZES.each_key do |size|
      within("[data-specimen=uncommon-#{size}]") do
        assert_selector ".card__art[data-art=failed]"
        assert_selector ".card__canvas", visible: :hidden
        assert_selector ".card__missing .card__missing-icon"
        assert_selector ".card__missing", text: "IMAGE UNAVAILABLE"
        assert_selector ".card__title", text: "GREEN HILLS"
        assert_selector ".card__rarity", text: "UNCOMMON"
        assert_selector ".card__year", text: "2019"
      end
    end
    assert_no_selector "[data-specimen=rare-m] .card__missing"
    # Under the art, until it is drawn (or when it is missing), a hatched box.
    assert_match(/\Arepeating-linear-gradient\(/, style("[data-specimen=uncommon-m] .card__art", "backgroundImage"))

    specimen = "[data-specimen=common-s]"
    art = "#{specimen} .card__art"
    # A stale mark, a hidden canvas and a stale tilt, as the snapshot Turbo caches on leaving.
    page.execute_script(<<~JS)
      const art = document.querySelector(#{art.to_json})
      art.dataset.art = "stale"
      art.querySelector("canvas").hidden = true
      const card = document.querySelector(#{"#{specimen} > .card".to_json})
      card.dataset.tilt = "held"
      card.style.setProperty("--tilt-rx", "5deg")
    JS
    find(".top-bar__home").click
    assert_selector ".hub"

    page.go_back
    assert_selector "#{art}[data-art=drawn] canvas:not([hidden])"
    assert_no_selector "#{specimen} > .card[data-tilt]"
    assert_not find("#{specimen} > .card").evaluate_script("this.hasAttribute('style')")
    painted = page.evaluate_script(<<~JS)
      document.querySelector(#{"#{art} canvas".to_json}).getContext("2d").getImageData(0, 0, 1, 1).data[3]
    JS
    assert_equal 255, painted

    visit back_office_cards_path(locale: :en)
    assert_selector SAMPLE_CARD, visible: :all
    urls = (1..30).map { |n| "#{sample_path}?copy=#{n}" }
    add_arts(urls)

    assert_selector "[data-test-art][data-art=drawn] canvas:not([hidden])", count: 30, visible: :all
    colors = page.evaluate_script(<<~JS)
      [...document.querySelectorAll("[data-test-art] canvas")].map((canvas) => {
        const data = canvas.getContext("2d").getImageData(0, 0, canvas.width, canvas.height).data
        const colors = new Set()
        for (let offset = 0; offset < data.length; offset += 4) {
          if (data[offset + 3] !== 0) colors.add(`${data[offset]},${data[offset + 1]},${data[offset + 2]}`)
        }
        return colors.size
      })
    JS
    assert_equal 30, colors.size
    assert colors.all? { |count| count.between?(2, 32) }, "each canvas should hold 2 to 32 colours: #{colors}"

    # The window never fetched them: the worker did.
    fetched = page.evaluate_script(<<~JS)
      ((urls) => {
        const names = new Set(performance.getEntriesByType("resource").map((entry) => entry.name))
        return urls.filter((url) => names.has(new URL(url, location.href).href))
      })(#{urls.to_json})
    JS
    assert_empty fetched
  end
end
