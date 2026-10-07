require "application_system_test_case"
require_relative "../support/game_packs"

# The countdown to the next pack in the top bar's packs chip, on the hub
# (R4): it ticks, and one second after zero the page refreshes by morphing,
# the new pack counted in menu 01 and the page's elements kept.
class CountdownTest < ApplicationSystemTestCase
  include GamePacks

  setup do
    @player = accounts_players(:player)
    OmniAuth.config.test_mode = true
    OmniAuth.config.mock_auth[:steam] = OmniAuth::AuthHash.new(provider: "steam", uid: "https://steamcommunity.com/openid/id/#{@player.steam_id}")
  end

  teardown do
    OmniAuth.config.mock_auth.delete(:steam)
    OmniAuth.config.test_mode = false
  end

  COUNTDOWN = ".top-bar .packs-chip__next[data-controller=countdown]".freeze
  BADGE = ".hub-menu .menu-item[aria-keyshortcuts='1'] .menu-item__badge".freeze

  test "the count rises after the countdown's refresh, morphed into the same page" do
    create_pack(@player)
    visit home_path(locale: :en)
    click_steam_sign_in
    assert_signed_in

    create_pack(@player, available_at: 4.seconds.from_now)
    visit home_path(locale: :en)
    assert_selector BADGE, text: "1", wait: 10
    assert_selector "#{COUNTDOWN} [data-countdown-target=clock]", text: /\A00:0[1-4]\z/, visible: :all
    page.execute_script("document.querySelector('.hub').testMark = 'kept'")

    assert_selector BADGE, text: "2", wait: 10
    assert_no_selector COUNTDOWN, visible: :all
    assert_equal "kept", page.evaluate_script("document.querySelector('.hub').testMark"), "the refresh should morph the hub, not replace it"
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
    assert_selector "#{COUNTDOWN}[data-countdown-seconds-value='2']", visible: :all
    page.execute_script("window.refreshes = 0; document.addEventListener('turbo:load', () => window.refreshes++)")

    # The first refresh comes at 3 s, the retry 5 s later.
    Timeout.timeout(15) { sleep 0.2 until page.evaluate_script("window.refreshes") >= 2 }
    assert_selector BADGE, text: "1", wait: 10
    assert_selector "#{COUNTDOWN}[data-countdown-seconds-value='2']", visible: :all

    travel_back
    assert_selector BADGE, text: "2", wait: 10
    assert_no_selector COUNTDOWN, visible: :all
  ensure
    travel_back
  end

  test "the refresh waits for a form being submitted (the daily booster's), which lands" do
    create_pack(@player)
    visit home_path(locale: :en)
    click_steam_sign_in
    assert_signed_in

    create_pack(@player, available_at: 2.seconds.from_now)
    visit home_path(locale: :en)
    # A slow submission: it stays in flight past the refresh's time.
    page.execute_script(<<~JS)
      const fetch = window.fetch
      window.fetch = (input, init) => init?.method?.toUpperCase() === "POST"
        ? new Promise((resolve) => setTimeout(resolve, 4000)).then(() => fetch(input, init))
        : fetch(input, init)
    JS
    within(".daily-booster") { click_on "Collect" }

    assert_text I18n.t("daily_bonuses.create.collected", locale: :en), wait: 10
    assert_selector BADGE, text: "3", wait: 10
  end

  test "elsewhere the packs chip's countdown stops at zero without refreshing the page" do
    create_pack(@player)
    visit home_path(locale: :en)
    click_steam_sign_in
    assert_signed_in

    create_pack(@player, available_at: 2.seconds.from_now)
    visit card_path(locale: :en, slug: "portal")
    page.execute_script("window.refreshes = 0; document.addEventListener('turbo:load', () => window.refreshes++)")

    assert_selector "#{COUNTDOWN} [data-countdown-target=clock]", text: "00:00", visible: :all, wait: 5
    sleep 2
    assert_equal 0, page.evaluate_script("window.refreshes")
  end
end
