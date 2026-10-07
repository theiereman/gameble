require "selenium-webdriver"

# A node removed from the page while Capybara reads it (a full page load after
# a form, a Turbo visit replacing a grid) is a stale element: Capybara retries
# its query on Selenium's StaleElementReferenceError. Recent chromedrivers
# (Chrome 13x and later) sometimes report that state as an UnknownError,
# "unhandled inspector error: Node with given id does not belong to the
# document", which Capybara does not know, so the test errors instead of
# waiting. This maps that answer back to the stale-element error, at the point
# where Selenium builds the error from chromedriver's response.
module ChromedriverStaleNodes
  STALE_NODE = "Node with given id does not belong to the document".freeze

  def error
    error = super
    return error unless error.is_a?(Selenium::WebDriver::Error::UnknownError) && error.message.include?(STALE_NODE)

    # Raised and rescued here so the stale error keeps chromedriver's own
    # trace as its cause, as the original error did.
    begin
      raise Selenium::WebDriver::Error::StaleElementReferenceError.new(error.message), cause: error
    rescue Selenium::WebDriver::Error::StaleElementReferenceError => stale
      stale
    end
  end
end

Selenium::WebDriver::Remote::Response.prepend(ChromedriverStaleNodes)
