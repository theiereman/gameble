require "test_helper"

# Sentry starts only where SENTRY_DSN is set; the suite runs without it.
class SentryInitializerTest < ActiveSupport::TestCase
  test "without SENTRY_DSN, Sentry is not initialised and sends nothing" do
    assert_predicate ENV["SENTRY_DSN"], :blank?
    assert_not Sentry.initialized?
    assert_nil Sentry.capture_message("gameble test event")
    assert_nil Sentry.capture_exception(RuntimeError.new("gameble test error"))
  end

  test "the Sentry environment is the destination's, or the Rails environment without one" do
    assert_equal "staging", SentryEnvironment.current("SENTRY_ENVIRONMENT" => "staging")
    assert_equal Rails.env, SentryEnvironment.current("SENTRY_ENVIRONMENT" => "")
    assert_equal Rails.env, SentryEnvironment.current({})
  end
end
