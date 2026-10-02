# Stubs the Steam Web API with Faraday's test adapter: no test calls Steam.
# Include in a test case, call `stub_steam_api` in setup and
# `unstub_steam_api` in teardown.
module SteamApiStubs
  API_KEY = "TEST0STEAM0API0KEY0123456789ABCD".freeze
  APP_LIST_PATH = "/IStoreService/GetAppList/v1/".freeze
  ITEMS_PATH = "/IStoreBrowseService/GetItems/v1/".freeze

  attr_reader :steam_stubs

  def stub_steam_api
    @steam_api_was = [ Steam::WebApi.adapter, Steam::WebApi.retry_interval, Rails.configuration.x.steam.api_key ]
    @steam_stubs = Faraday::Adapter::Test::Stubs.new
    Steam::WebApi.adapter = [ :test, @steam_stubs ]
    Steam::WebApi.retry_interval = 0
    Rails.configuration.x.steam.api_key = API_KEY
  end

  def unstub_steam_api
    Steam::WebApi.adapter, Steam::WebApi.retry_interval, Rails.configuration.x.steam.api_key = @steam_api_was
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
end
