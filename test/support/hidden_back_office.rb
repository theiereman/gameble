# The back-office answers whoever is not staff as an unknown address does:
# the static 404 page. Errors render here as in production, not as the test
# environment's detailed page, so the body can be compared.
#
#   get back_office_path(locale: :fr)
#   assert_unknown_address
module HiddenBackOffice
  DETAILED = "action_dispatch.show_detailed_exceptions"

  def self.included(test_case)
    test_case.setup do
      @detailed_exceptions = Rails.application.env_config[DETAILED]
      Rails.application.env_config[DETAILED] = false
    end
    test_case.teardown { Rails.application.env_config[DETAILED] = @detailed_exceptions }
  end

  def assert_unknown_address(message = nil)
    assert_response :not_found, message
    assert_equal Rails.public_path.join("404.html").read, response.body, message
  end
end
