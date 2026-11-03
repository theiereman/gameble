require "application_system_test_case"
require_relative "../support/steam_sign_in"

# The card face as the server draws it (back-office card preview,
# administrators only): its art drawn on its canvas, the missing image, and
# the art drawn again after a Turbo restore.
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

  test "every specimen with an art has it drawn on its canvas" do
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
