require "application_system_test_case"

class LandingBoardingTest < ApplicationSystemTestCase
  setup { resize_to(1500, 1000) }

  def rect(selector) = page.evaluate_script("document.querySelector(\"#{selector}\").getBoundingClientRect().toJSON()")

  def background_image(selector) = page.evaluate_script("getComputedStyle(document.querySelector(\"#{selector}\")).backgroundImage")

  test "the way aboard wears no hazard stripe on the desktop and the phone, the support panel keeping its own" do
    [ [ 1500, 1000 ], [ 390, 900 ] ].each do |width, height|
      resize_to(width, height)
      visit home_path(locale: :en)

      assert_selector ".landing-boarding__panel.panel--brackets", visible: :all
      assert_equal "none", background_image(".landing-boarding__panel"), "at #{width}px"
      assert_includes background_image(".landing-support"), "repeating-linear-gradient", "at #{width}px"
    end
  end

  test "the Steam sign-in sits at the top right of the way aboard, beside its copy" do
    visit home_path(locale: :en)
    panel = rect(".landing-boarding__panel")
    copy = rect(".landing-boarding__copy")
    button = rect(".landing-boarding .steam-sign-in")

    assert_in_delta panel["right"], button["right"], 40
    assert_operator button["top"], :<, copy["top"] + 80
    assert_operator button["left"], :>, copy["right"] - 1
  end

  test "under a phone width the Steam sign-in stacks below the copy" do
    resize_to(390, 900)
    visit home_path(locale: :en)
    copy = rect(".landing-boarding__copy")
    button = rect(".landing-boarding .steam-sign-in")

    assert_operator button["top"], :>=, copy["bottom"]
  end
end
