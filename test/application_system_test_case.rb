require "test_helper"

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  # Headless Chrome. CHROME_BIN points at another Chrome-compatible browser, such as Chromium locally.
  driven_by :selenium, using: :headless_chrome, screen_size: [ 1400, 1400 ] do |options|
    options.binary = ENV["CHROME_BIN"] if ENV["CHROME_BIN"].present?
  end
end
