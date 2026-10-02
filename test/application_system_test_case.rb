require "test_helper"

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  # Headless Chrome. CHROME_BIN points at another Chrome-compatible browser, such as Chromium locally.
  # The browser window size; a test that resizes the window restores it to this.
  SCREEN_SIZE = [ 1400, 1400 ].freeze

  driven_by :selenium, using: :headless_chrome, screen_size: SCREEN_SIZE do |options|
    options.binary = ENV["CHROME_BIN"] if ENV["CHROME_BIN"].present?
  end
end
