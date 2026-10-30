require "faraday"
require "faraday/retry"

module Steam
  class WebApi
    BASE_URL = "https://api.steampowered.com".freeze
    REDACTED = "[FILTERED]".freeze
    RETRY_STATUSES = [ 429, 500, 502, 503, 504 ].freeze

    class Error < StandardError; end
    class BrokenKey < Error; end
    class Unavailable < Error; end

    UNAVAILABLE = [ Faraday::TooManyRequestsError, Faraday::RequestTimeoutError, Faraday::ServerError, Faraday::TimeoutError,
      Faraday::ConnectionFailed, Faraday::SSLError ].freeze

    AppListPage = Data.define(:apps, :have_more_results, :last_appid, :malformed)

    class_attribute :adapter, default: [ Faraday.default_adapter ]
    class_attribute :retry_interval, default: 2.0
    class_attribute :player_summary_deadline, default: 5.0
    class_attribute :owned_games_deadline, default: 10.0

    def initialize(api_key: Rails.configuration.x.steam.api_key)
      @api_key = api_key.to_s
    end

    def get_app_list(last_appid:, max_results:)
      body = get("/IStoreService/GetAppList/v1/", { include_games: true, last_appid: last_appid, max_results: max_results })
      response = body["response"] if body.is_a?(Hash)
      # An empty last page still has a `response` object.
      raise Error, "GetAppList answered without a response object" unless response.is_a?(Hash)
      raise Error, "GetAppList answered apps that are not a list" unless response.fetch("apps", []).is_a?(Array)

      entries = response.fetch("apps", [])
      apps = entries.filter_map { |app| normalize_app(app) }
      more = response["have_more_results"] == true
      last_appid = RawValue.integer(response["last_appid"], min: 0, max: RawValue::INT4_MAX)
      if more && entries.any? && apps.empty? && last_appid.nil?
        raise Error, "GetAppList answered #{entries.size} malformed apps and no cursor, with more to come"
      end

      AppListPage.new(apps: apps, have_more_results: more, last_appid: last_appid, malformed: entries.size - apps.size)
    end

    # GetItems takes at most 100 appids a call.
    def get_items(appids:, context:, data_request:)
      input = { ids: appids.map { |appid| { appid: appid } }, context: context, data_request: data_request }
      body = get("/IStoreBrowseService/GetItems/v1/", { input_json: input.to_json })
      response = body["response"] if body.is_a?(Hash)
      raise Error, "GetItems answered without a response object" unless response.is_a?(Hash)

      items = response["store_items"]
      raise Error, "GetItems answered store items that are not a list" unless items.is_a?(Array)
      raise Error, "GetItems answered no store item for #{appids.size} appids" if items.empty? && appids.any?

      # Steam answers an unknown appid as `id: 0, success: 15`, which matches no requested appid.
      requested = appids.to_set
      items.each_with_object({}) do |item, by_appid|
        next unless item.is_a?(Hash)

        appid = RawValue.integer(item["appid"] || item["id"], min: 1, max: RawValue::INT4_MAX)
        by_appid[appid] = item if appid && requested.include?(appid)
      end
    end

    def get_tag_list(language:)
      body = get("/IStoreService/GetTagList/v1/", { language: language })
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

    def get_player_summary(steamid:)
      body = get("/ISteamUser/GetPlayerSummaries/v2/", { steamids: steamid }, connection_without_retry, deadline: player_summary_deadline)
      response = body["response"] if body.is_a?(Hash)
      raise Error, "GetPlayerSummaries answered without a response object" unless response.is_a?(Hash)
      raise Error, "GetPlayerSummaries answered players that are not a list" unless response["players"].is_a?(Array)

      player = response["players"].find { |entry| entry.is_a?(Hash) && entry["steamid"].to_s == steamid.to_s }
      name = player && player["personaname"]
      raise Error, "GetPlayerSummaries answered a persona name that is not a string" unless name.nil? || name.is_a?(String)

      name&.strip.presence
    end

    # Steam answers a private library as a `response` without `games`.
    def get_owned_games(steamid:)
      params = { steamid: steamid, include_appinfo: false, include_played_free_games: true, skip_unvetted_apps: false }
      body = get("/IPlayerService/GetOwnedGames/v1/", params, connection_without_retry, deadline: owned_games_deadline)
      response = body["response"] if body.is_a?(Hash)
      raise Error, "GetOwnedGames answered without a response object" unless response.is_a?(Hash)
      return unless response.key?("games")
      raise Error, "GetOwnedGames answered games that are not a list" unless response["games"].is_a?(Array)

      appids = response["games"].filter_map do |game|
        RawValue.integer(game["appid"], min: 1, max: RawValue::INT4_MAX) if game.is_a?(Hash)
      end
      raise Error, "GetOwnedGames answered #{response["games"].size} games and no readable appid" if appids.empty? && response["games"].any?

      appids
    end

    def inspect
      "#<#{self.class.name}>"
    end

    def redact(message)
      return message.to_s if @api_key.empty?

      [ @api_key, CGI.escape(@api_key), ERB::Util.url_encode(@api_key) ].uniq.reduce(message.to_s) do |text, secret|
        text.gsub(secret, REDACTED)
      end
    end

    private

    # Net::HTTP bounds each phase of a request apart; only Timeout bounds them together.
    def get(path, params, connection = self.connection, deadline: nil)
      raise BrokenKey, "STEAM_API_KEY is not set" if @api_key.empty?

      Timeout.timeout(deadline, Faraday::TimeoutError, "no answer within #{deadline} s") do
        connection.get(path, params.merge(key: @api_key)).body
      end
    rescue Faraday::UnauthorizedError, Faraday::ForbiddenError => error
      raise BrokenKey.new(redact("#{error.class}: #{error.message}")), cause: nil
    rescue *UNAVAILABLE => error
      raise Unavailable.new(redact("#{error.class}: #{error.message}")), cause: nil
    rescue Faraday::Error, JSON::ParserError => error
      raise Error.new(redact("#{error.class}: #{error.message}")), cause: nil
    end

    def normalize_app(app)
      return unless app.is_a?(Hash)

      appid = RawValue.integer(app["appid"], min: 1, max: RawValue::INT4_MAX)
      return unless appid

      {
        appid: appid,
        name: RawValue.string(app["name"]).to_s,
        last_modified: RawValue.integer(app["last_modified"], min: 0, max: RawValue::TIMESTAMP_MAX)&.then { |timestamp| Time.at(timestamp).utc },
        price_change_number: RawValue.integer(app["price_change_number"], min: 0, max: RawValue::INT8_MAX)
      }
    end

    # raise_error wraps retry: the retry middleware sees the 429 or 5xx response itself.
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

    def connection_without_retry
      @connection_without_retry ||= Faraday.new(url: BASE_URL) do |f|
        f.response :raise_error
        f.response :json
        f.adapter(*adapter)
      end
    end
  end
end
