require "capybara/selenium/driver"
require "capybara/selenium/driver_specializations/chrome_driver"

# Capybara 3.40 resets a session with the CDP call Storage.clearDataForOrigin
# for origin "*", which chromedriver 158 and later refuse as "* is not a valid
# URL": the reset then fails and the session's cookies reach the next test.
# The call is sent for the app server's origin instead.
module ChromedriverStorageReset
  def execute_cdp(cmd, params = {})
    return super unless cmd == "Storage.clearDataForOrigin" && params[:origin] == "*"

    server = Capybara.current_session.server
    super(cmd, params.merge(origin: server.base_url)) if server
  end
end

Capybara::Selenium::Driver::ChromeDriver.prepend(ChromedriverStorageReset)
