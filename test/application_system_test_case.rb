require "test_helper"

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  # Headless Chrome. CHROME_BIN points at another Chrome-compatible browser, such as Chromium locally.
  # The browser window size; a test that resizes the window restores it to this.
  SCREEN_SIZE = [ 1400, 1400 ].freeze

  driven_by :selenium, using: :headless_chrome, screen_size: SCREEN_SIZE do |options|
    options.binary = ENV["CHROME_BIN"] if ENV["CHROME_BIN"].present?
  end

  # Each test starts without cookies. Capybara's reset clears them, then
  # waits for the requests still running, and every answer re-sends the
  # session cookie: a request the last page left in flight (the collection's
  # keepalive "seen" POST outlives the page) would sign the next test's
  # browser in. The cookies are cleared once more after that wait.
  def after_teardown
    Capybara.reset_sessions!
    page.driver.browser.execute_cdp("Network.clearBrowserCookies")
  ensure
    super
  end

  # Signing in and out through the shell's top bar (story 8.1): the official
  # Steam image for a visitor, the player menu's "Sign out" for a player.
  def click_steam_sign_in
    find(".top-bar .steam-sign-in__button").click
  end

  def assert_signed_in
    assert_selector ".top-bar .player-chip"
  end

  def sign_out
    find(".top-bar .player-chip__button").click
    within("#player-menu") { click_on "Sign out" }
  end

  def assert_signed_out
    assert_selector ".top-bar .steam-sign-in__button"
  end
end
