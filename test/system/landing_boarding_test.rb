require "application_system_test_case"

class LandingBoardingTest < ApplicationSystemTestCase
  setup { resize_to(1500, 1000) }

  def rect(selector) = page.evaluate_script("document.querySelector(\"#{selector}\").getBoundingClientRect().toJSON()")

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
