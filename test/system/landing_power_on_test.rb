require "application_system_test_case"

class LandingPowerOnTest < ApplicationSystemTestCase
  VIEWPORT = [ 1500, 1000 ].freeze

  setup { resize_to(*VIEWPORT) }

  def drift(layer) = page.evaluate_script("document.getElementById('atmosphere').style.getPropertyValue('--landing-drift-#{layer}')")

  test "a gauge marker moves focus to its heading" do
    visit home_path(locale: :en)
    find("nav a[aria-label='03 · How it works']").click

    assert_selector "#landing-how:focus"
  end
end
