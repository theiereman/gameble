require "faraday"
require "faraday/retry"

module Steam
  # The Steam store API (AD-4, AD-19), keyless, over Faraday. Its endpoints
  # share a rate limit of about 200 requests per 5 minutes, so the client
  # spaces its own requests: each one waits until `interval` seconds have
  # passed since the previous one of this process, on a monotonic clock,
  # retries included (the spacing sits inside the retry middleware).
  #
  # A 5xx is retried with backoff by faraday-retry. A 429 or 403 (the store's
  # two ways of saying "too many") is not: it raises
  # Steam::StoreApi::RateLimited at once, for the import job to wait minutes
  # rather than seconds (a Retry-After obeyed here could hold one attempt for
  # minutes). Any other failure, and an answer that is not
  # the one asked for, raises Steam::StoreApi::Error.
  #
  #   Steam::StoreApi.new.app_details(620)
  #   # => { "success" => true, "data" => { "steam_appid" => 620, "genres" => [...], "legal_notice" => "...", ... } }
  class StoreApi
    BASE_URL = "https://store.steampowered.com".freeze
    APP_DETAILS_PATH = "/api/appdetails".freeze
    RATE_LIMIT_STATUSES = [ 403, 429 ].freeze
    RETRY_STATUSES = [ 500, 502, 503, 504 ].freeze

    class Error < StandardError; end
    class RateLimited < Error; end

    # The Faraday adapter, as arguments to `Faraday::Connection#adapter`.
    class_attribute :adapter, default: [ Faraday.default_adapter ]
    # Seconds before the first retry; doubled on each retry.
    class_attribute :retry_interval, default: 2.0
    # Seconds between two requests of this process (store rate limit).
    class_attribute :interval, default: 2.0
    # Called with the seconds to wait; tests swap in a recorder.
    class_attribute :sleeper, default: ->(seconds) { sleep(seconds) }

    @spacing_lock = Mutex.new
    @last_request_at = nil

    class << self
      # Waits, through `sleeper`, until `interval` has passed since the
      # previous request of this process, then records this one.
      def space_request
        @spacing_lock.synchronize do
          now = Process.clock_gettime(Process::CLOCK_MONOTONIC)
          wait = @last_request_at ? @last_request_at + interval - now : 0
          sleeper.call(wait) if wait.positive?
          @last_request_at = now + [ wait, 0 ].max
        end
      end

      # Forgets the previous request (tests).
      def reset_spacing!
        @spacing_lock.synchronize { @last_request_at = nil }
      end
    end

    # Faraday middleware: every request, retries included, is spaced.
    class Spacing < Faraday::Middleware
      def call(env)
        StoreApi.space_request
        @app.call(env)
      end
    end

    # The store's answer for one app, in English prices and text, with its
    # basic data and genres: `{ "success" => true|false, "data" => {...} }`.
    # A body that is null, not JSON, or has no entry for the appid raises.
    def app_details(appid)
      body = get(APP_DETAILS_PATH, appids: appid, cc: "us", l: "english", filters: "basic,genres")
      raise Error, "appdetails answered no object for #{appid}" unless body.is_a?(Hash)

      entry = body[appid.to_s]
      raise Error, "appdetails answered no entry for #{appid}" unless entry.is_a?(Hash)

      entry
    end

    private

    def get(path, params)
      connection.get(path, params).body
    rescue Faraday::ClientError => error
      raise rate_limited?(error) ? RateLimited.new("#{error.class}: #{error.message}") : Error.new("#{error.class}: #{error.message}"), cause: nil
    rescue Faraday::Error, JSON::ParserError => error
      raise Error.new("#{error.class}: #{error.message}"), cause: nil
    end

    def rate_limited?(error)
      RATE_LIMIT_STATUSES.include?(error.response_status)
    end

    # raise_error wraps retry, which wraps the spacing: each attempt is spaced,
    # and raise_error raises once the retries are spent.
    def connection
      @connection ||= Faraday.new(url: BASE_URL, request: { timeout: 30, open_timeout: 10 }) do |f|
        f.response :raise_error
        f.request :retry,
          max: 4,
          interval: retry_interval,
          backoff_factor: 2,
          max_interval: 60,
          retry_statuses: RETRY_STATUSES,
          methods: %i[get]
        f.use Spacing
        f.response :json
        f.adapter(*adapter)
      end
    end
  end
end
