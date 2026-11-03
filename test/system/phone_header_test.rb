require "application_system_test_case"
require_relative "../support/game_packs"
require_relative "../support/steam_sign_in"

# The top-level header on a 390 px phone: the wordmark home button and one merged
# capsule counter, a bar that hides while scrolling down, and a version line
# that sits in the page flow.
class PhoneHeaderTest < ApplicationSystemTestCase
  include GamePacks
  include SteamSignIn

  TOUCH_MIN = 44

  setup do
    resize_to(390, 844)
    @player = accounts_players(:player)
    2.times { create_pack(@player) }
    create_pack(@player, available_at: 5.minutes.from_now)
    mock_steam_sign_in(@player.steam_id)
    visit home_path(locale: :en)
    click_steam_sign_in
    assert_selector ".top-bar--top-level .top-bar__phone-home", visible: true
  end

  test "the header holds the wordmark home button and one capsule counter, each at least 44 px, and clips nothing" do
    assert_no_selector ".top-bar .player-chip", visible: true
    assert_no_selector ".top-bar .packs-chip", visible: true
    assert_selector ".top-bar .bank-counter__item", count: 2
    assert_operator box(".top-bar__phone-home")["height"], :>=, TOUCH_MIN
    assert_operator box(".top-bar__phone-home")["width"], :>=, TOUCH_MIN
    assert_operator box(".bank-counter__button")["height"], :>=, TOUCH_MIN
    assert page.evaluate_script("document.querySelector('.top-bar__inner').scrollWidth <= window.innerWidth"), "the header should not overflow"
    assert_selector ".top-bar__title, h1", text: /./, visible: :all
  end

  test "tapping the counter opens the detail with both capsule counts and the countdown, and it links to the booster" do
    find(".bank-counter__button").click

    within("#bank-detail") do
      assert_text(/capsules/i)
      assert_text(/special/i)
      assert_selector ".bank-detail__clock", text: /\d\d:\d\d/
      click_link(text: /open a capsule/i)
    end
    assert_current_path booster_path(locale: :en)
  end

  test "the header hides on a downward scroll, stays while the detail is open, and returns on an upward scroll" do
    page.execute_script(<<~JS)
      const spacer = document.createElement("div")
      spacer.style.height = "3000px"
      document.querySelector("main").append(spacer)
    JS

    scroll_to_y(700)
    assert_selector ".top-bar[data-hidden]", visible: :all
    scroll_to_y(500)
    assert_no_selector ".top-bar[data-hidden]", visible: :all

    find(".bank-counter__button").click
    scroll_to_y(900)
    assert_selector "#bank-detail", visible: true
    assert_no_selector ".top-bar[data-hidden]", visible: :all
  end

  test "the version line sits below the content and above the tab bar" do
    page.execute_script("window.scrollTo(0, document.documentElement.scrollHeight)")

    assert_selector ".app-version", visible: true
    version = box(".app-version")
    assert_equal "static", page.evaluate_script("getComputedStyle(document.querySelector('.app-version')).position")
    assert_operator version["top"], :>=, box("main")["bottom"]
    assert_operator version["bottom"], :<=, box(".tab-bar")["top"]
    assert_operator box(".app-version__legal")["height"], :>=, TOUCH_MIN
  end

  private

  def box(selector)
    page.evaluate_script("(() => { const r = document.querySelector(#{selector.to_json}).getBoundingClientRect(); return { top: r.top, bottom: r.bottom, width: r.width, height: r.height } })()")
  end

  def scroll_to_y(offset)
    page.execute_script("window.scrollTo(0, #{offset})")
  end
end
