require "test_helper"
require_relative "support/chromedriver_stale_nodes"

# CI's runner is slower than a development machine: a page re-rendered with
# sixty cards, or a redirect after a form, can take more than Capybara's
# default two seconds. The wait is a ceiling, never a delay.
Capybara.default_max_wait_time = 5

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  # Headless Chrome. CHROME_BIN points at another Chrome-compatible browser, such as Chromium locally.
  # The browser window size. One browser serves every test of a worker, so a
  # test that resizes the window (a phone layout) is followed by one that
  # finds the hub's menu hidden unless the size is restored: the teardown
  # below restores it for every test.
  SCREEN_SIZE = [ 1400, 1400 ].freeze

  driven_by :selenium, using: :headless_chrome, screen_size: SCREEN_SIZE do |options|
    options.binary = ENV["CHROME_BIN"] if ENV["CHROME_BIN"].present?
  end

  # The fixtures' cover and store hosts do not exist: the browser fails their
  # requests at once instead of waiting on name resolution, which a reveal
  # would otherwise wait out as long as the card's art.
  setup do
    browser = page.driver.browser
    browser.execute_cdp("Network.enable")
    browser.execute_cdp("Network.setBlockedURLs", urls: [ "*://*.example.test/*" ])
  end

  teardown do
    resize_to(*SCREEN_SIZE)
  end

  def resize_to(width, height)
    page.driver.browser.manage.window.resize_to(width, height)
  end

  def eventually(message, &condition)
    page.document.synchronize { raise Capybara::ExpectationNotMet, message unless condition.call }
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
