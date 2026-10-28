require "application_system_test_case"
require_relative "../support/second_season"
require_relative "../support/steam_sign_in"

# The allocation screen shown once after a season is published: signing in
# lands on it, continuing leads to the hub, and its button stays in view.
class SeasonAllocationTest < ApplicationSystemTestCase
  include SecondSeason
  include SteamSignIn

  setup do
    @player = accounts_players(:player)
    publish_second_season(@player)
    mock_steam_sign_in(@player.steam_id)
  end

  def sign_in_to_the_screen
    visit home_path(locale: :en)
    click_steam_sign_in
    assert_selector "h1", text: "ALLOCATION · SEASON 2"
  end

  def assert_no_sideways_scroll
    assert page.evaluate_script("document.documentElement.scrollWidth <= window.innerWidth"), "the page should not scroll sideways"
  end

  test "on a desktop signing in lands on the screen, which lists the carried tiers in two columns, and continuing leads to the hub" do
    sign_in_to_the_screen

    assert_selector ".allocation-section__title", text: "YOUR TIERS IN THE NEXT SEASON"
    assert_selector ".allocation-row", count: 3
    lefts = page.evaluate_script("[ ...document.querySelectorAll('.allocation-row') ].map((row) => Math.round(row.getBoundingClientRect().left))")
    assert_equal 2, lefts.uniq.size
    assert_no_sideways_scroll

    click_button "Continue"

    assert_current_path home_path(locale: :en)
  end

  test "on a 390 × 844 phone the list is one column and the button stays in view above the tab bar" do
    page.driver.browser.manage.window.resize_to(390, 844)
    sign_in_to_the_screen

    assert_equal 1, page.evaluate_script("new Set([ ...document.querySelectorAll('.allocation-row') ].map((row) => Math.round(row.getBoundingClientRect().left))).size")
    assert page.evaluate_script("document.querySelector('.allocation__go .button').getBoundingClientRect().bottom <= window.innerHeight"), "the button should be in view"
    assert_no_sideways_scroll
  end
end
