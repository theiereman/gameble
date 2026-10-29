require "test_helper"

class FilterParameterLoggingTest < ActiveSupport::TestCase
  def filtered(params) = ActiveSupport::ParameterFilter.new(Rails.application.config.filter_parameters).filter(params)

  test "Steam's OpenID answer is kept out of the logs, the Steam id with it" do
    params = { "openid.claimed_id" => "https://steamcommunity.com/openid/id/76561197960287930", "openid.sig" => "abc", "locale" => "en" }

    assert_equal({ "openid.claimed_id" => "[FILTERED]", "openid.sig" => "[FILTERED]", "locale" => "en" }, filtered(params))
  end
end
