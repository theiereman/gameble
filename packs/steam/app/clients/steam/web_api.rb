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
  #
  #   Steam::WebApi.new.get_items(appids: [ 10, 20 ], context: { language: "english", country_code: "US" }, data_request: { include_reviews: true })
  #   # => { 10 => { "appid" => 10, "success" => 1, "reviews" => { ... }, ... } }
  #
  #   Steam::WebApi.new.get_tag_list(language: "english")
  #   # => [{ tagid: 19, name: "Action" }, ...]
  #
  #   Steam::WebApi.new.get_player_summary(steamid: "76561197960287930")
  #   # => "Gabe" | nil
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

    # The store items of IStoreBrowseService/GetItems for `appids` (at most
    # 100 a call), raw, keyed by appid. Only the requested appids are keys:
    # Steam answers an unknown appid as `id: 0, success: 15`, which matches
    # none, so an appid missing from the hash got no answer. What each item
    # holds depends on `data_request`; the caller reads it.
    def get_items(appids:, context:, data_request:)
      input = { ids: appids.map { |appid| { appid: appid } }, context: context, data_request: data_request }
      body = get("/IStoreBrowseService/GetItems/v1/", input_json: input.to_json)
      response = body["response"] if body.is_a?(Hash)
      raise Error, "GetItems answered without a response object" unless response.is_a?(Hash)

      items = response["store_items"]
      raise Error, "GetItems answered store items that are not a list" unless items.is_a?(Array)
      raise Error, "GetItems answered no store item for #{appids.size} appids" if items.empty? && appids.any?

      requested = appids.to_set
      items.each_with_object({}) do |item, by_appid|
        next unless item.is_a?(Hash)

        appid = (item["appid"] || item["id"]).to_i
        by_appid[appid] = item if requested.include?(appid)
      end
    end

    # Steam's store tags named in `language`, from IStoreService/GetTagList.
    # An answer without a response object, without a tag list, or whose
    # list names no tag raises.
    def get_tag_list(language:)
      body = get("/IStoreService/GetTagList/v1/", language: language)
      response = body["response"] if body.is_a?(Hash)
      raise Error, "GetTagList answered without a response object" unless response.is_a?(Hash)
      raise Error, "GetTagList answered tags that are not a list" unless response["tags"].is_a?(Array)

      tags = response["tags"].filter_map do |tag|
        next unless tag.is_a?(Hash) && tag["tagid"].is_a?(Integer) && tag["name"].is_a?(String) && tag["name"].present?

        { tagid: tag["tagid"], name: tag["name"].strip }
      end
      raise Error, "GetTagList answered no tag" if tags.empty?

      tags
    end

    # The persona name of one player, from ISteamUser/GetPlayerSummaries, for
    # a sign-in (CAP-8): one attempt, no retry, a 5 s timeout, so a slow
    # Steam never holds a sign-in long. Stripped; nil when Steam answers no
    # player with that id or an empty name. A failure or a malformed answer
    # raises Steam::WebApi::Error, the key redacted.
    def get_player_summary(steamid:)
      body = get("/ISteamUser/GetPlayerSummaries/v2/", { steamids: steamid }, summary_connection)
      response = body["response"] if body.is_a?(Hash)
      raise Error, "GetPlayerSummaries answered without a response object" unless response.is_a?(Hash)
      raise Error, "GetPlayerSummaries answered players that are not a list" unless response["players"].is_a?(Array)

      player = response["players"].find { |entry| entry.is_a?(Hash) && entry["steamid"].to_s == steamid.to_s }
      name = player && player["personaname"]
      raise Error, "GetPlayerSummaries answered a persona name that is not a string" unless name.nil? || name.is_a?(String)

      name&.strip.presence
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

    def get(path, params, connection = self.connection)
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

    # For a request made while a player waits (a sign-in): no retry and a
    # short timeout.
    def summary_connection
      @summary_connection ||= Faraday.new(url: BASE_URL, request: { timeout: 5, open_timeout: 5 }) do |f|
        f.response :raise_error
        f.response :json
        f.adapter(*adapter)
      end
    end
  end
end
