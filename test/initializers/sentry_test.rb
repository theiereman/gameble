require "test_helper"

# AD-21: Sentry starts only where SENTRY_DSN is set; the suite runs without it.
class SentryInitializerTest < ActiveSupport::TestCase
  test "without SENTRY_DSN, Sentry is not initialised and sends nothing" do
    assert_predicate ENV["SENTRY_DSN"], :blank?
    assert_not Sentry.initialized?
    assert_nil Sentry.capture_message("gameble test event")
    assert_nil Sentry.capture_exception(RuntimeError.new("gameble test error"))
  end
end
