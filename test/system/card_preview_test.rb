require "application_system_test_case"
require_relative "../support/steam_sign_in"

# The card face as the server draws it at every size (back-office card
# preview, administrators only): its art, the missing image, a long title,
# a Légendaire's glitter in and out of the viewport, a Turbo restore.
class CardPreviewTest < ApplicationSystemTestCase
  include SteamSignIn

  SIZES = { "s" => [ 112, 168, 50, 51 ], "m" => [ 160, 240, 72, 74 ], "l" => [ 208, 312, 94, 97 ], "xl" => [ 240, 360, 109, 112 ] }.freeze
  SPECIMENS = Catalog::Rarity::TIERS.values.product(SIZES.keys).map { |parts| parts.join("-") } +
    Catalog::Rarity::TIERS.values.map { |rarity| "#{rarity}-m-booster" }

  setup do
    administrator = accounts_players(:administrator)
    mock_steam_sign_in(administrator.steam_id)
    visit home_path(locale: :en)
    click_steam_sign_in
    assert_signed_in
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

  test "every specimen is drawn at its size, its art at its art size" do
    visit_preview

    assert_equal SPECIMENS, page.all("[data-specimen]").map { it["data-specimen"] }
    SPECIMENS.each do |specimen|
      size = specimen.split("-")[1]
      width, height, art_width, art_height = SIZES.fetch(size)
      card = "[data-specimen=#{specimen}] > .card"
      assert_equal [ width, height ], box(card), "#{specimen} card"
      assert_equal [ 2 * art_width, 2 * art_height ], box("#{card} .card__art"), "#{specimen} art box"
      assert_equal [ art_width, art_height ], page.evaluate_script("(() => { const c = document.querySelector(#{"#{card} .card__canvas".to_json}); return [ c.width, c.height ] })()")
      # Every part fits inside the body: nothing overflows the card.
      inside = page.evaluate_script(<<~JS)
        (() => {
          const card = document.querySelector(#{card.to_json}).getBoundingClientRect()
          return [...document.querySelectorAll(#{"#{card} .card__body > *".to_json})].every((part) => {
            const r = part.getBoundingClientRect()
            return r.top >= card.top && r.bottom <= card.bottom && r.left >= card.left && r.right <= card.right
          })
        })()
      JS
      assert inside, "#{specimen}: a part leaves the card"
    end

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
    take_screenshot
  end

  test "a missing art shows the picture and its words, and keeps the frame, title and footer" do
    visit_preview

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
  end

  test "a long title shows two lines at most and keeps its full text" do
    visit_preview

    SIZES.each_key do |size|
      selector = "[data-specimen=epic-#{size}] .card__title"
      title = page.find(selector)
      assert_equal "The Long Chronicles of the Amethyst Archive and the Keys Its Keepers Lost at Sea", title.text(:all)
      line = page.evaluate_script("parseFloat(getComputedStyle(document.querySelector(#{selector.to_json})).lineHeight)")
      assert_equal 2 * line, box(selector)[1], "#{size}: two lines"
    end
    short = "[data-specimen=rare-s] .card__title"
    assert_equal page.evaluate_script("parseFloat(getComputedStyle(document.querySelector(#{short.to_json})).lineHeight)"), box(short)[1]
  end

  test "a legendary face's glitter twinkles only while in view, never under reduced motion; the reflection stays" do
    visit_preview
    specimen = "[data-specimen=legendary-xl]"
    glint = "#{specimen} .card__flake:not([data-flash]) .card__flake-glint"

    scroll_to(find(specimen), align: :center)
    assert_selector "#{specimen} > .card[data-in-view]"
    assert_selector glint, style: { "animation-name" => "card-glitter-twinkle" }
    assert_selector "#{specimen} .card__reflection--iridescence"
    assert_no_selector "[data-specimen=rare-xl] .card__glitter, [data-specimen=rare-xl] .card__reflection--iridescence"
    assert_no_selector ".card__holo, .card__foil, .card__glare", visible: :all

    page.execute_script("window.scrollTo(0, 0)")
    assert_no_selector "#{specimen} > .card[data-in-view]"
    assert_equal "none", style(glint, "animationName")

    scroll_to(find(specimen), align: :center)
    assert_selector "#{specimen} > .card[data-in-view]"
    reduce_motion(true)
    assert_selector glint, style: { "animation-name" => "none" }
    assert_equal "block", style("#{specimen} .card__reflection--strips", "display")
    reduce_motion(false)

    booster = "[data-specimen=legendary-m-booster]"
    scroll_to(find(booster), align: :center)
    assert_selector "#{booster} > .card[data-in-view]"
    assert_selector "#{booster} .card__glitter .card__flake"
    assert_selector "#{booster} .card__flake:not([data-flash]) .card__flake-glint", style: { "animation-name" => "card-glitter-twinkle" }
    %w[rare epic].each do |rarity|
      assert_no_selector "[data-specimen=#{rarity}-m-booster] .card__glitter, [data-specimen=#{rarity}-m-booster] .card__reflection--iridescence"
    end
  end

  test "a Turbo restore visit draws the art again, from a clean face" do
    visit_preview
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
  end
end
