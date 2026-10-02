require "faraday"
require "faraday/retry"

module Steam
  # The Steam Web API (AD-4, AD-19), over Faraday. A 429 or 5xx is retried
  # with exponential backoff by faraday-retry; once the retries are spent, or
  # on any other failure, it raises Steam::WebApi::Error.
  #
  # The API key comes from config.x.steam.api_key (config/initializers/steam.rb)
  # and travels as the `key` query parameter. It never leaves this class: every
  # error raised here has the key redacted from its message and carries no
  # cause, so neither the logs, Sentry nor the import run's errors see it.
  #
  #   Steam::WebApi.new.get_app_list(last_appid: 0, max_results: 10_000)
  #   # => #<Steam::WebApi::AppListPage apps: [{ appid:, name:, last_modified:, price_change_number: }], have_more_results:, last_appid:>
  class WebApi
    BASE_URL = "https://api.steampowered.com".freeze
    REDACTED = "[FILTERED]".freeze
    RETRY_STATUSES = [ 429, 500, 502, 503, 504 ].freeze

    class Error < StandardError; end

    AppListPage = Data.define(:apps, :have_more_results, :last_appid)

    # The Faraday adapter, as arguments to `Faraday::Connection#adapter`.
    # Tests swap in Faraday's test adapter: `Steam::WebApi.adapter = [ :test, stubs ]`.
    class_attribute :adapter, default: [ Faraday.default_adapter ]
    # Seconds before the first retry; doubled on each retry.
    class_attribute :retry_interval, default: 2.0

    def initialize(api_key: Rails.configuration.x.steam.api_key)
      @api_key = api_key.to_s
    end

    # One page of IStoreService/GetAppList, games only, after `last_appid`.
    # The list is ordered by appid; `last_appid` of the page is the cursor of
    # the next one.
    def get_app_list(last_appid:, max_results:)
      body = get("/IStoreService/GetAppList/v1/", include_games: true, last_appid: last_appid, max_results: max_results)
      response = body["response"] if body.is_a?(Hash)
      # An empty last page still has a `response` object; anything else is
      # not an answer, and must not end the run as if the list were done.
      raise Error, "GetAppList answered without a response object" unless response.is_a?(Hash)
      raise Error, "GetAppList answered apps that are not a list" unless response.fetch("apps", []).is_a?(Array)

      AppListPage.new(
        apps: Array(response["apps"]).map { |app| normalize_app(app) },
        have_more_results: response["have_more_results"] == true,
        last_appid: response["last_appid"]&.to_i
      )
    end

    # Keeps the key out of inspections (consoles, error reports).
    def inspect
      "#<#{self.class.name}>"
    end

    # The message with the API key replaced, in plain and URL-encoded forms.
    def redact(message)
      return message.to_s if @api_key.empty?

      [ @api_key, CGI.escape(@api_key), ERB::Util.url_encode(@api_key) ].uniq.reduce(message.to_s) do |text, secret|
        text.gsub(secret, REDACTED)
      end
    end

    private

    def get(path, params)
      raise Error, "STEAM_API_KEY is not set" if @api_key.empty?

      connection.get(path, params.merge(key: @api_key)).body
    rescue Faraday::Error, JSON::ParserError => error
      raise Error.new(redact("#{error.class}: #{error.message}")), cause: nil
    end

    def normalize_app(app)
      {
        appid: Integer(app.fetch("appid")),
        name: app["name"].to_s,
        last_modified: app["last_modified"] && Time.at(app["last_modified"].to_i).utc,
        price_change_number: app["price_change_number"]&.to_i
      }
    end

    # raise_error wraps retry: the retry middleware sees the 429 or 5xx
    # response itself, and raise_error raises once the retries are spent.
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
        f.response :json
        f.adapter(*adapter)
      end
    end
  end
end
