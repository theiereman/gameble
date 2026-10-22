require "application_system_test_case"

class LandingLampTest < ApplicationSystemTestCase
  STAGE = ".landing-lamp__stage".freeze
  FOUND = ".landing-lamp__card.is-found".freeze
  COUNT = ".landing-lamp__count".freeze

  def veil_transform
    page.evaluate_script("document.querySelector('.landing-lamp__veil').style.transform")
  end

  def move_mouse_to(element, x = nil, y = nil)
    action = page.driver.browser.action
    x ? action.move_to(element.native, x, y).perform : action.move_to(element.native).perform
  end

  test "the lamp sweeps on its own and finds the games, the count rising" do
    visit landing_path(locale: :en)

    assert_selector "[data-controller=lamp-field][data-lamp-mode=auto]"
    assert_selector FOUND, minimum: 1, wait: 15
    assert_selector COUNT, text: %r{\A[1-6] / 6\z}
    assert_selector ".landing-lamp__mode--auto", text: "Auto sweep"
  end

  test "a mouse over the field takes the lamp, which finds the card under it" do
    visit landing_path(locale: :en)
    assert_selector "[data-lamp-lit]", wait: 5

    card = find(".landing-lamp__card--2")
    move_mouse_to(card)

    assert_selector "[data-lamp-mode=manual]"
    assert_selector ".landing-lamp__card--2.is-found.is-lit", wait: 5
    assert_selector ".landing-lamp__mode--manual", text: "Manual sweep"
  end

  test "the lamp sweeps again once the mouse has rested" do
    visit landing_path(locale: :en)
    assert_selector "[data-lamp-lit]", wait: 5
    move_mouse_to(find(STAGE), 30, 30)
    assert_selector "[data-lamp-mode=manual]"

    assert_selector "[data-lamp-mode=auto]", wait: 6
  end

  test "under reduced motion the lamp rests on the first card with two found and jumps to the mouse" do
    visit landing_path(locale: :en)
    page.execute_script("document.documentElement.dataset.motion = 'reduced'")

    assert_selector "[data-lamp-mode=still]"
    assert_selector FOUND, count: 2
    assert_selector COUNT, text: "2 / 6"
    resting = veil_transform

    move_mouse_to(find(".landing-lamp__card--3"))
    assert_selector ".landing-lamp__card--3.is-found.is-lit"
    assert_selector COUNT, text: "3 / 6"
    assert_not_equal resting, veil_transform
  end

  test "on a phone the lamp sweeps in its own band with five cards" do
    resize_to(390, 844)
    visit landing_path(locale: :en)

    assert_selector ".landing-lamp__card", count: 5
    assert_selector COUNT, text: %r{\A[0-5] / 5\z}
    assert_selector FOUND, minimum: 1, wait: 15
    assert_no_selector ".landing-lamp__modes", visible: :visible
  end
end
