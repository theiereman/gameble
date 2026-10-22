require "application_system_test_case"

class LandingPowerOnTest < ApplicationSystemTestCase
  VIEWPORT = [ 1500, 1000 ].freeze

  setup { resize_to(*VIEWPORT) }

  def power_of(id) = page.evaluate_script("document.getElementById('#{id}').closest('.landing-module').dataset.power")

  def eventually(message, &condition)
    page.document.synchronize { raise Capybara::ExpectationNotMet, message unless condition.call }
  end

  def drift(layer) = page.evaluate_script("document.getElementById('atmosphere').style.getPropertyValue('--landing-drift-#{layer}')")

  def scroll_to_module(id)
    page.execute_script("window.scrollTo(0, document.getElementById('#{id}').closest('.landing-module').getBoundingClientRect().top + window.scrollY - 600)")
  end

  test "scrolling powers a module on once and it stays on" do
    visit landing_path(locale: :en)
    assert_selector ".landing-module[data-power=armed]", minimum: 1, visible: :all
    assert_equal "armed", power_of("landing-roadmap")

    scroll_to_module("landing-roadmap")
    assert_selector ".landing-module[data-power=on]:has(#landing-roadmap)"

    page.execute_script("window.scrollTo(0, 0)")
    assert_no_selector "nav a[aria-current=location][aria-label='06 · Roadmap']"
    assert_equal "on", power_of("landing-roadmap")
  end

  test "a gauge marker moves focus to its heading and is the only current one" do
    visit landing_path(locale: :en)
    find("nav a[aria-label='03 · How it works']").click

    assert_equal "landing-how", page.evaluate_script("document.activeElement.id")
    assert_selector "nav[aria-label='Position on the page'] a[aria-current=location]", count: 1
    assert_selector "a[aria-current=location][aria-label='03 · How it works']"
  end

  test "under a narrow window the gauge is not displayed" do
    resize_to(1200, 1000)
    visit landing_path(locale: :en)

    assert_no_selector "nav[aria-label='Position on the page']"
  end

  test "under reduced motion the star layers stay still while scrolling" do
    visit landing_path(locale: :en)
    page.execute_script("document.documentElement.dataset.motion = 'reduced'")
    page.execute_script("window.scrollTo(0, 1500)")

    assert_no_selector "nav a[aria-current=location][aria-label='00 · Mission']"
    assert_equal "0px", drift("near")
  end

  test "scrolling moves the star layers by a share of the scroll" do
    visit landing_path(locale: :en)
    page.execute_script("window.scrollTo(0, 1000)")

    assert_no_selector "nav a[aria-current=location][aria-label='00 · Mission']"
    eventually("the layers did not drift") { drift("near") == "120px" && drift("far") == "50px" }
  end
end
