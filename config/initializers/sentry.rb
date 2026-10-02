# Production errors go to Sentry (AD-21), and only errors: no tracing, no
# profiling. Sentry starts only when SENTRY_DSN is set, so development and
# test send nothing. No personal data leaves: send_default_pii is off (no
# request bodies, query strings, cookies or IP headers), and whatever request
# data an event still carries is filtered by the app's filter_parameters. The
# player id is the only thing attached about a player (ApplicationController).
if ENV["SENTRY_DSN"].present?
  Sentry.init do |config|
    config.dsn = ENV["SENTRY_DSN"]
    config.environment = Rails.env
    config.release = ENV["KAMAL_VERSION"] if ENV["KAMAL_VERSION"].present?
    config.send_default_pii = false
    config.traces_sample_rate = 0.0
    # Profiling stays off by leaving profiles_sample_rate unset (nil): any
    # number, even 0.0, makes Sentry warn that the stackprof gem is missing.

    config.before_send = lambda do |event, _hint|
      if (request = event.request)
        filter = ActiveSupport::ParameterFilter.new(Rails.application.config.filter_parameters)
        request.data = filter.filter(request.data) if request.data.is_a?(Hash)
        request.query_string = filter.filter(request.query_string) if request.query_string.is_a?(Hash)
      end
      event
    end
  end
end
