require "application_system_test_case"

class LandingPowerOnTest < ApplicationSystemTestCase
  VIEWPORT = [ 1500, 1000 ].freeze

  setup { resize_to(*VIEWPORT) }

  def power_of(id) = page.evaluate_script("document.getElementById('#{id}').closest('.landing-module').dataset.power")

  def name_opacity(label) = page.evaluate_script("getComputedStyle(document.querySelector(\"nav a[aria-label='#{label}'] .landing-side-gauge__name\")).opacity")

  def drift(layer) = page.evaluate_script("document.getElementById('atmosphere').style.getPropertyValue('--landing-drift-#{layer}')")

  def scroll_to_module(id)
    page.execute_script("window.scrollTo(0, document.getElementById('#{id}').closest('.landing-module').getBoundingClientRect().top + window.scrollY - 600)")
  end

  test "scrolling powers a module on once and it stays on" do
    visit home_path(locale: :en)
    assert_selector ".landing-module[data-power=armed]", minimum: 1, visible: :all
    assert_equal "armed", power_of("landing-roadmap")

    scroll_to_module("landing-roadmap")
    assert_selector ".landing-module[data-power=on]:has(#landing-roadmap)"

    page.execute_script("window.scrollTo(0, 0)")
    assert_no_selector "nav a[aria-current=location][aria-label='06 · Roadmap']"
    assert_equal "on", power_of("landing-roadmap")
  end

  test "a gauge marker moves focus to its heading and is the only current one" do
    visit home_path(locale: :en)
    find("nav a[aria-label='03 · How it works']").click

    assert_equal "landing-how", page.evaluate_script("document.activeElement.id")
    assert_selector "nav[aria-label='Position on the page'] a[aria-current=location]", count: 1
    assert_selector "a[aria-current=location][aria-label='03 · How it works']"
  end

  test "the gauge sits on the left, names a hovered marker and every marker when hovered as a whole" do
    visit home_path(locale: :en)
    box = page.evaluate_script("document.querySelector('nav[aria-label=\"Position on the page\"]').getBoundingClientRect().toJSON()")
    assert_operator box["right"], :<, VIEWPORT.first / 2

    assert_selector ".landing-side-gauge__name", count: 10, visible: :all
    marker = find("nav a[aria-label='03 · How it works']")
    marker.hover
    eventually("the hovered marker shows its name") { name_opacity("03 · How it works") == "1" }
    eventually("the other markers show theirs while the component is hovered") { name_opacity("06 · Roadmap") == "1" }

    page.driver.browser.action.move_to_location(VIEWPORT.first / 2, 10).perform
    eventually("the names hide again") { name_opacity("03 · How it works") == "0" }
  end

  test "a marker name shares the number's typeface and swells with it, over a feathered backdrop" do
    visit home_path(locale: :en)
    style = lambda do |selector, property|
      page.evaluate_script("getComputedStyle(document.querySelector(\"nav a[aria-label='03 · How it works'] #{selector}\")).#{property}")
    end
    %w[fontFamily fontWeight textTransform letterSpacing].each do |property|
      assert_equal style.call("span:first-child", property), style.call(".landing-side-gauge__name", property)
    end
    assert_match(/blur\(/, style.call(".landing-side-gauge__name", "backdropFilter"))
    assert_match(/linear-gradient/, style.call(".landing-side-gauge__name", "maskImage"))
    assert_equal "none", style.call(".landing-side-gauge__name", "textShadow")
    assert_equal "none", style.call(".landing-side-gauge__name", "borderStyle")
    far_name = page.evaluate_script("getComputedStyle(document.querySelector(\"nav a[aria-label='06 · Roadmap'] .landing-side-gauge__name\")).color")
    far_number = page.evaluate_script("getComputedStyle(document.querySelector(\"nav a[aria-label='06 · Roadmap'] span:first-child\")).color")
    assert_equal far_number, far_name
    assert_not_equal "rgb(102, 192, 244)", far_name

    find("nav a[aria-label='03 · How it works']").hover
    eventually("the name scales with the number") do
      style.call(".landing-side-gauge__name", "transform").start_with?("matrix(1.5,")
    end
    eventually("the name takes the accent with its number") do
      style.call(".landing-side-gauge__name", "color") == "rgb(102, 192, 244)"
    end
  end

  test "a marker is hoverable well beyond its number" do
    visit home_path(locale: :en)
    zone = page.evaluate_script("(() => { const r = document.querySelector(\"nav a[aria-label='03 · How it works']\").getBoundingClientRect(); return { width: r.width, height: r.height } })()")
    assert_operator zone["height"], :>=, 40
    assert_operator zone["width"], :>=, 30
  end

  test "under a narrow window the gauge is not displayed" do
    resize_to(1200, 1000)
    visit home_path(locale: :en)

    assert_no_selector "nav[aria-label='Position on the page']"
  end

  test "under reduced motion the star layers stay still while scrolling" do
    visit home_path(locale: :en)
    page.execute_script("document.documentElement.dataset.motion = 'reduced'")
    page.execute_script("window.scrollTo(0, 1500)")

    assert_no_selector "nav a[aria-current=location][aria-label='00 · Mission']"
    assert_equal "0px", drift("near")
  end

  test "scrolling moves the star layers by a share of the scroll" do
    visit home_path(locale: :en)
    page.execute_script("window.scrollTo(0, 1000)")

    assert_no_selector "nav a[aria-current=location][aria-label='00 · Mission']"
    eventually("the layers did not drift") { drift("near") == "120px" && drift("far") == "50px" }
  end
end
