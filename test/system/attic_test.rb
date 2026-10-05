require "application_system_test_case"

class AtticTest < ApplicationSystemTestCase
  PHONE = [ 390, 844 ].freeze

  def resize_to(width, height)
    page.driver.browser.manage.window.resize_to(width, height)
  end

  # Horizontal centres, in viewport pixels, of the attic frame and the chest.
  def centres
    page.evaluate_script(<<~JS)
      (() => {
        const frame = document.querySelector(".attic").getBoundingClientRect()
        const chest = document.querySelector(".attic__object--chest").getBoundingClientRect()
        return { frame: frame.left + frame.width / 2, chest: chest.left + chest.width / 2 }
      })()
    JS
  end

  test "on a desktop the whole room shows, its six objects named" do
    resize_to(*SCREEN_SIZE)
    visit home_path(locale: :fr)

    assert_selector ".attic__name", count: 6
    assert_selector ".attic__name", text: "Le coffre"
    assert_equal 0, page.evaluate_script("document.querySelector('.attic').scrollLeft")
    assert_no_selector ".attic[tabindex]"
    take_screenshot
  end

  test "on a phone the room pans sideways and opens centred on the chest" do
    resize_to(*PHONE)
    visit home_path(locale: :en)

    assert_selector ".attic__object--chest"
    assert_selector ".top-bar form.steam-sign-in[action='/auth/steam']", visible: true
    assert page.evaluate_script("document.querySelector('.attic').scrollWidth > document.querySelector('.attic').clientWidth"), "the room should overflow its frame"
    assert page.evaluate_script("document.documentElement.scrollWidth <= window.innerWidth"), "the page itself should not scroll sideways"
    assert_operator page.evaluate_script("document.querySelector('.attic').scrollLeft"), :>, 0
    assert_selector ".attic[tabindex='0']"

    positions = centres
    assert_in_delta positions["frame"], positions["chest"], 2
    take_screenshot
  ensure
    resize_to(*SCREEN_SIZE)
  end
end
