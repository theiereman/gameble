require "application_system_test_case"
require_relative "../support/game_packs"

# The countdown to the next pack under the attic chest (R4): it ticks, and
# one second after zero the page refreshes by morphing, the new pack counted
# and the attic's pan kept.
class CountdownTest < ApplicationSystemTestCase
  include GamePacks

  PHONE = [ 390, 844 ].freeze

  setup do
    @player = accounts_players(:player)
    OmniAuth.config.test_mode = true
    OmniAuth.config.mock_auth[:steam] = OmniAuth::AuthHash.new(provider: "steam", uid: "https://steamcommunity.com/openid/id/#{@player.steam_id}")
  end

  teardown do
    OmniAuth.config.mock_auth.delete(:steam)
    OmniAuth.config.test_mode = false
    page.driver.browser.manage.window.resize_to(*SCREEN_SIZE)
  end

  test "the count rises after the countdown's refresh, and the attic keeps its pan" do
    page.driver.browser.manage.window.resize_to(*PHONE)
    create_pack(@player)
    visit home_path(locale: :en)
    click_steam_sign_in
    assert_signed_in

    create_pack(@player, available_at: 4.seconds.from_now)
    visit home_path(locale: :en)
    assert_button "Open a pack (1)"
    assert_selector ".attic__countdown [data-countdown-target=clock]", text: /\A00:0[1-4]\z/
    page.execute_script("document.querySelector('.attic').scrollLeft = 40")

    assert_button "Open a pack (2)", wait: 10
    assert_no_selector ".attic__countdown"
    assert_equal 40, page.evaluate_script("document.querySelector('.attic').scrollLeft")
    assert_selector ".attic[tabindex='0']"
  end

  test "a refresh that brings back the same countdown is tried again until the pack comes" do
    create_pack(@player)
    visit home_path(locale: :en)
    click_steam_sign_in
    assert_signed_in

    # The server's clock stands still: every refresh answers 2 seconds left.
    travel_to(Time.current)
    create_pack(@player, available_at: 2.seconds.from_now)
    visit home_path(locale: :en)
    assert_selector ".attic__countdown[data-countdown-seconds-value='2']"
    page.execute_script("window.refreshes = 0; document.addEventListener('turbo:load', () => window.refreshes++)")

    # The first refresh comes at 3 s, the retry 5 s later.
    Timeout.timeout(15) { sleep 0.2 until page.evaluate_script("window.refreshes") >= 2 }
    assert_button "Open a pack (1)"
    assert_selector ".attic__countdown[data-countdown-seconds-value='2']"

    travel_back
    assert_button "Open a pack (2)", wait: 10
    assert_no_selector ".attic__countdown"
  ensure
    travel_back
  end

  test "the refresh waits for a pack being opened, which reaches its result page" do
    create_pack(@player)
    visit home_path(locale: :en)
    click_steam_sign_in
    assert_signed_in

    create_pack(@player, available_at: 2.seconds.from_now)
    visit home_path(locale: :en)
    # A slow opening: the submission stays in flight past the refresh's time.
    page.execute_script(<<~JS)
      const fetch = window.fetch
      window.fetch = (input, init) => init?.method?.toUpperCase() === "POST"
        ? new Promise((resolve) => setTimeout(resolve, 4000)).then(() => fetch(input, init))
        : fetch(input, init)
    JS
    click_on "Open a pack (1)"

    assert_selector "h1", text: "Your pack, Brother", wait: 10
    assert_current_path %r{/en/packs/}
  end
end
