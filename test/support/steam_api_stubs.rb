# Stubs the Steam Web API and the store API with Faraday's test adapter: no
# test calls Steam. Include in a test case, call `stub_steam_api` in setup
# and `unstub_steam_api` in teardown. The store API's spacing is 0 and its
# sleeper records the waits in `store_sleeps`.
module SteamApiStubs
  API_KEY = "TEST0STEAM0API0KEY0123456789ABCD".freeze
  APP_LIST_PATH = "/IStoreService/GetAppList/v1/".freeze
  ITEMS_PATH = "/IStoreBrowseService/GetItems/v1/".freeze
  TAG_LIST_PATH = "/IStoreService/GetTagList/v1/".freeze
  APP_DETAILS_PATH = "/api/appdetails".freeze
  PLAYER_SUMMARIES_PATH = "/ISteamUser/GetPlayerSummaries/v2/".freeze

  attr_reader :steam_stubs, :store_sleeps

  def stub_steam_api
    @steam_api_was = [ Steam::WebApi.adapter, Steam::WebApi.retry_interval, Rails.configuration.x.steam.api_key ]
    @store_api_was = [ Steam::StoreApi.adapter, Steam::StoreApi.retry_interval, Steam::StoreApi.interval, Steam::StoreApi.sleeper ]
    @steam_stubs = Faraday::Adapter::Test::Stubs.new
    @store_sleeps = []
    Steam::WebApi.adapter = [ :test, @steam_stubs ]
    Steam::WebApi.retry_interval = 0
    Rails.configuration.x.steam.api_key = API_KEY
    sleeps = @store_sleeps
    Steam::StoreApi.adapter = [ :test, @steam_stubs ]
    Steam::StoreApi.retry_interval = 0
    Steam::StoreApi.interval = 0
    Steam::StoreApi.sleeper = ->(seconds) { sleeps << seconds }
    Steam::StoreApi.reset_spacing!
  end

  def unstub_steam_api
    Steam::WebApi.adapter, Steam::WebApi.retry_interval, Rails.configuration.x.steam.api_key = @steam_api_was
    Steam::StoreApi.adapter, Steam::StoreApi.retry_interval, Steam::StoreApi.interval, Steam::StoreApi.sleeper = @store_api_was
    Steam::StoreApi.reset_spacing!
  end

  # A GetAppList page answered for the request that starts after `after`.
  def stub_app_list_page(after:, appids:, more:)
    apps = appids.map { |appid| { "appid" => appid, "name" => "Game #{appid}", "last_modified" => 1_700_000_000 + appid, "price_change_number" => appid * 10 } }
    response = { "apps" => apps }
    response["have_more_results"] = true if more
    response["last_appid"] = appids.last if more && appids.any?
    steam_stubs.get("#{APP_LIST_PATH}?last_appid=#{after}") do
      [ 200, { "Content-Type" => "application/json" }, { "response" => response }.to_json ]
    end
  end

  def stub_app_list_status(status, after: nil)
    path = after.nil? ? APP_LIST_PATH : "#{APP_LIST_PATH}?last_appid=#{after}"
    steam_stubs.get(path) { [ status, { "Content-Type" => "application/json" }, "{}" ] }
  end

  # Answers every GetItems call from `items`, { appid => item }, in the order
  # of the requested appids: an appid mapped to nil is left out of the
  # answer; an appid not in `items` is answered as Steam answers an unknown
  # one, `id: 0, success: 15`. Returns the parsed input_json of each call.
  def stub_get_items(items)
    calls = []
    steam_stubs.get(ITEMS_PATH) do |env|
      input = JSON.parse(env.params.fetch("input_json"))
      calls << input
      store_items = input.fetch("ids").filter_map do |id|
        appid = id.fetch("appid")
        items.key?(appid) ? items[appid] : { "item_type" => 0, "id" => 0, "success" => 15 }
      end
      [ 200, { "Content-Type" => "application/json" }, { "response" => { "store_items" => store_items } }.to_json ]
    end
    calls
  end

  # A store item with its review summary.
  def reviewed_item(appid, count, percent: 90)
    summary = { "review_count" => count, "percent_positive" => percent, "review_score" => 8, "review_score_label" => "Very Positive" }
    { "item_type" => 0, "id" => appid, "success" => 1, "visible" => true, "name" => "Game #{appid}", "appid" => appid,
      "reviews" => { "summary_filtered" => summary } }
  end

  # A store item Steam answers without any review summary.
  def unreviewed_item(appid)
    { "item_type" => 0, "id" => appid, "success" => 1, "visible" => true, "name" => "Game #{appid}", "appid" => appid }
  end

  # A store item Steam answers without success (not on the store).
  def unavailable_item(appid, success: 2)
    { "item_type" => 0, "id" => appid, "success" => success, "appid" => appid }
  end

  # Answers every GetItems call from the items of the language it asks for,
  # { "english" => { appid => item }, "french" => { ... } }, with the rules of
  # stub_get_items (nil leaves the appid out; an appid not in the hash is
  # answered `id: 0, success: 15`). Returns the parsed input_json of each call.
  def stub_get_items_by_language(items_by_language)
    calls = []
    steam_stubs.get(ITEMS_PATH) do |env|
      input = JSON.parse(env.params.fetch("input_json"))
      calls << input
      items = items_by_language.fetch(input.dig("context", "language"), {})
      store_items = input.fetch("ids").filter_map do |id|
        appid = id.fetch("appid")
        items.key?(appid) ? items[appid] : { "item_type" => 0, "id" => 0, "success" => 15 }
      end
      [ 200, { "Content-Type" => "application/json" }, { "response" => { "store_items" => store_items } }.to_json ]
    end
    calls
  end

  # A store item of a game as GetItems answers it with basic info, assets,
  # release and tags (shaped on the real answers probed on 2026-10-02).
  # `reviews:` adds a review summary, so one item serves the review pass too.
  def detailed_item(appid, name: "Game #{appid}", description: "The <b>best</b> game #{appid}.", type: 0,
                    capsule: "library_600x900.jpg", release: { "steam_release_date" => 1_303_171_200 },
                    publishers: [ "Publisher #{appid}" ], tags: [ { "tagid" => 19, "weight" => 900 }, { "tagid" => 492, "weight" => 1200 } ],
                    reviews: nil)
    assets = { "asset_url_format" => "steam/apps/#{appid}/${FILENAME}?t=1745363004", "main_capsule" => "capsule_616x353.jpg",
      "header" => "header.jpg", "library_hero" => "library_hero.jpg" }
    assets["library_capsule"] = capsule if capsule
    item = { "item_type" => 0, "id" => appid, "success" => 1, "visible" => true, "name" => name,
      "store_url_path" => "app/#{appid}/#{name.to_s.tr(" ", "_")}/", "appid" => appid,
      "basic_info" => { "short_description" => description,
        "publishers" => publishers.map { |publisher| { "name" => publisher, "creator_clan_account_id" => 4 } },
        "developers" => [ { "name" => "Studio #{appid}", "creator_clan_account_id" => 5 } ] },
      "tagids" => tags.map { |tag| tag["tagid"] }, "tags" => tags, "assets" => assets, "release" => release }
    item["type"] = type unless type.nil?
    item["reviews"] = { "summary_filtered" => { "review_count" => reviews, "percent_positive" => 90, "review_score" => 8, "review_score_label" => "Very Positive" } } if reviews
    item
  end

  # The French store item of a game: GetItems localizes the short
  # description only, the name comes back as in English.
  def french_item(appid, name: "Game #{appid}", description: "Le <b>meilleur</b> jeu #{appid}.")
    detailed_item(appid, name: name, description: description)
  end

  # Answers GetTagList with `tags`, { tagid => name }. Returns the params of
  # each call.
  def stub_get_tag_list(tags = { 19 => "Action", 492 => "Indie", 1664 => "Puzzle" })
    calls = []
    steam_stubs.get(TAG_LIST_PATH) do |env|
      calls << env.params
      body = { "response" => { "version_hash" => "1", "tags" => tags.map { |tagid, name| { "tagid" => tagid, "name" => name } } } }
      [ 200, { "Content-Type" => "application/json" }, body.to_json ]
    end
    calls
  end

  # Answers every appdetails call from `entries`, { appid => entry }: an entry
  # Hash is answered under the appid's key; :null answers `null`, :missing an
  # object without the appid's key, :not_json a body that is not JSON. An
  # appid not in `entries` is answered `{ success: false }`. Returns the
  # params of each call.
  def stub_app_details(entries)
    calls = []
    steam_stubs.get(APP_DETAILS_PATH) do |env|
      calls << env.params
      appid = env.params.fetch("appids").to_i
      entry = entries.fetch(appid, { "success" => false })
      body = case entry
      when :null then "null"
      when :missing then { "1" => { "success" => false } }.to_json
      when :not_json then "<html>Access Denied</html>"
      else { appid.to_s => entry }.to_json
      end
      [ 200, { "Content-Type" => "application/json; charset=utf-8" }, body ]
    end
    calls
  end

  # An appdetails entry of a game with `filters=basic,genres`.
  def app_details_entry(appid, genres: [ "Action", "Free to Play" ], legal_notice: "&copy; Studio #{appid}<br>All rights reserved.")
    data = { "type" => "game", "name" => "Game #{appid}", "steam_appid" => appid, "required_age" => 0, "is_free" => false,
      "short_description" => "A game.", "supported_languages" => "English", "header_image" => "https://example.test/header.jpg" }
    data["legal_notice"] = legal_notice unless legal_notice.nil?
    data["genres"] = genres.each_with_index.map { |description, index| { "id" => (index + 1).to_s, "description" => description } } unless genres.nil?
    { "success" => true, "data" => data }
  end

  # Answers GetPlayerSummaries for `steam_id` with `name` as its persona name
  # (nil answers no player at all). Returns the params of each call.
  def stub_player_summary(steam_id, name)
    calls = []
    steam_stubs.get(PLAYER_SUMMARIES_PATH) do |env|
      calls << env.params
      players = name.nil? ? [] : [ { "steamid" => steam_id, "communityvisibilitystate" => 3, "personaname" => name, "avatar" => "https://avatars.example.test/a.jpg" } ]
      [ 200, { "Content-Type" => "application/json" }, { "response" => { "players" => players } }.to_json ]
    end
    calls
  end

  # Answers GetPlayerSummaries with `status`, or raises a connection failure
  # for :connection_failed. Returns the params of each call.
  def stub_player_summary_failure(status = 503)
    calls = []
    steam_stubs.get(PLAYER_SUMMARIES_PATH) do |env|
      calls << env.params
      raise Faraday::ConnectionFailed, "failed to open #{env.url}" if status == :connection_failed

      [ status, { "Content-Type" => "application/json" }, "{}" ]
    end
    calls
  end
end
