require "application_system_test_case"
require_relative "../support/steam_sign_in"

class LandingMotionSwitchTest < ApplicationSystemTestCase
  include SteamSignIn

  PHONE = [ 390, 844 ].freeze

  setup do
    @player = accounts_players(:player)
    mock_steam_sign_in(@player.steam_id)
  end

  def motion = page.evaluate_script("document.documentElement.dataset.motion")

  def box(selector) = find(selector).evaluate_script("this.getBoundingClientRect().toJSON()")

  def overlap?(first, second)
    first["left"] < second["right"] && second["left"] < first["right"] &&
      first["top"] < second["bottom"] && second["top"] < first["bottom"]
  end

  test "a visitor turns animations down, keeps it on the next load, and signs in with the account's setting on" do
    visit home_path(locale: :en)
    assert_selector ".motion-switch[aria-pressed=false]"
    click_on "Reduced motion"

    assert_selector ".motion-switch[aria-pressed=true]"
    assert_equal "reduced", motion
    visit home_path(locale: :en)
    assert_selector ".motion-switch[aria-pressed=true]"
    assert_equal "reduced", motion

    click_steam_sign_in
    assert_signed_in
    assert_equal true, @player.reload.reduced_motion
  end

  test "switching it back off hands the page back to the system" do
    visit home_path(locale: :en)
    click_on "Reduced motion"
    assert_selector ".motion-switch[aria-pressed=true]"
    click_on "Reduced motion"

    assert_selector ".motion-switch[aria-pressed=false]"
    assert_nil motion
  end

  { fr: "Animations réduites", en: "Reduced motion" }.each do |locale, label|
    test "on a phone in #{locale}, the top bar shows the wordmark and the sign-in image, and no motion switch" do
      resize_to(*PHONE)
      visit home_path(locale:)

      assert_selector ".top-bar .top-bar__wordmark", visible: true
      assert_selector ".top-bar .top-bar__end a[href*='/sign-in']", visible: true
      assert_no_selector ".motion-switch", visible: true
      assert_no_button label
      assert_not overlap?(box(".top-bar .top-bar__wordmark"), box(".top-bar .top-bar__end a[href*='/sign-in']")), "the sign-in link sits over the wordmark"
    end
  end
end
