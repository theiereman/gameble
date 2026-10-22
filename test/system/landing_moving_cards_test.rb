require "application_system_test_case"

class LandingMovingCardsTest < ApplicationSystemTestCase
  CARDS = ".moving-cards .moving-card".freeze

  FINE_POINTER = <<~JS.freeze
    const matchMedia = window.matchMedia.bind(window)
    const fine = "(hover: hover) and (pointer: fine)"
    window.matchMedia = (query) => {
      const real = matchMedia(query)
      if (query !== fine) return real
      const fake = Object.create(real)
      Object.defineProperty(fake, "matches", { value: true })
      fake.addEventListener = () => {}
      fake.removeEventListener = () => {}
      return fake
    }
  JS

  setup do
    @fine_pointer = page.driver.browser.execute_cdp("Page.addScriptToEvaluateOnNewDocument", source: FINE_POINTER)["identifier"]
  end

  teardown do
    page.driver.browser.execute_cdp("Page.removeScriptToEvaluateOnNewDocument", identifier: @fine_pointer)
  end

  def scroll_to(y) = page.execute_script("window.scrollTo(0, #{y})")

  def card_box(key) = page.evaluate_script("(() => { const r = document.querySelector('.moving-card[data-key=#{key}]').getBoundingClientRect(); return { left: r.left, right: r.right, top: r.top } })()")

  def content_box = page.evaluate_script("(() => { const r = document.querySelector('.landing').getBoundingClientRect(); return { left: r.left, right: r.right } })()")

  def scrollable = page.evaluate_script("document.documentElement.scrollHeight - window.innerHeight")

  def scroll_to_card(key, fraction: 0.5)
    anchor = page.evaluate_script("Number(document.querySelector('.moving-card[data-key=#{key}]').dataset.anchor)")
    scroll_to((anchor * scrollable - (fraction - 0.5) * 100).round)
  end

  test "a wide desktop shows the cards in the gutters, never over the content, moving faster than the scroll" do
    resize_to(1800, 1000)
    visit home_path(locale: :en)
    assert_selector CARDS, count: 5, visible: :all

    scroll_to_card("epic")
    eventually("the epic card shows") { !page.evaluate_script("document.querySelector('.moving-card[data-key=epic]').hidden") }
    box = card_box("epic")
    content = content_box
    assert_operator box["right"], :<=, content["left"]

    before = card_box("epic")["top"]
    page.execute_script("window.scrollBy(0, 100)")
    eventually("the card moved more than the scroll") { (before - card_box("epic")["top"]) > 120 }
  end

  test "a dragged card keeps its offset while the page scrolls" do
    resize_to(1800, 1000)
    visit home_path(locale: :en)
    scroll_to_card("epic")
    eventually("the epic card shows") { !page.evaluate_script("document.querySelector('.moving-card[data-key=epic]').hidden") }

    card = find(".moving-card[data-key=epic] .moving-card__body", visible: :all)
    before = card_box("epic")["left"]
    page.driver.browser.action.move_to(card.native).click_and_hold.move_by(100, 0).release.perform
    eventually("the card followed the pointer") { (card_box("epic")["left"] - before - 100).abs < 2 }

    page.execute_script("window.scrollBy(0, 30)")
    eventually("the offset is kept") { (card_box("epic")["left"] - before - 100).abs < 40 }
    assert_operator card_box("epic")["left"], :>, before + 60
  end

  test "a click beside the cards reaches the content" do
    resize_to(1800, 1000)
    visit home_path(locale: :en)
    assert_selector CARDS, count: 5, visible: :all

    assert_equal "none", page.evaluate_script("getComputedStyle(document.querySelector('.moving-cards')).pointerEvents")
    assert_equal "landing-hero", page.evaluate_script("document.elementFromPoint(900, 300).closest('.landing-hero') && 'landing-hero'")
  end

  test "a narrow window has no moving card in the DOM, and widening adds them" do
    resize_to(1200, 900)
    visit home_path(locale: :en)
    assert_selector ".moving-cards", visible: :all
    assert_no_selector CARDS, visible: :all

    resize_to(1800, 1000)
    assert_selector CARDS, count: 5, visible: :all
  end

  test "reduced motion shows none and switching it live adds or removes them" do
    resize_to(1800, 1000)
    visit home_path(locale: :en)
    assert_selector CARDS, count: 5, visible: :all

    page.execute_script("document.documentElement.dataset.motion = 'reduced'")
    assert_no_selector CARDS, visible: :all

    page.execute_script("document.documentElement.dataset.motion = 'full'")
    assert_selector CARDS, count: 5, visible: :all
  end

  test "tabbing into the content fades the layer and it returns when focus leaves" do
    resize_to(1800, 1000)
    visit home_path(locale: :en)
    assert_selector CARDS, count: 5, visible: :all

    20.times do
      break if page.evaluate_script("document.getElementById('main').contains(document.activeElement)")
      page.driver.browser.action.send_keys(:tab).perform
    end
    assert_selector ".moving-cards.is-faded", visible: :all
    eventually("the layer is transparent") { page.evaluate_script("getComputedStyle(document.querySelector('.moving-cards')).opacity") == "0" }

    page.execute_script("document.activeElement.blur()")
    assert_no_selector ".moving-cards.is-faded", visible: :all
  end

  test "the layer is hidden from assistive technology and holds nothing focusable" do
    resize_to(1800, 1000)
    visit home_path(locale: :en)
    assert_selector CARDS, count: 5, visible: :all

    assert_selector ".moving-cards[aria-hidden=true]", visible: :all
    assert_no_selector ".moving-cards a, .moving-cards button, .moving-cards [tabindex]", visible: :all
  end
end
