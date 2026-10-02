# Stubs the Steam Web API with Faraday's test adapter: no test calls Steam.
# Include in a test case, call `stub_steam_api` in setup and
# `unstub_steam_api` in teardown.
module SteamApiStubs
  API_KEY = "TEST0STEAM0API0KEY0123456789ABCD".freeze
  APP_LIST_PATH = "/IStoreService/GetAppList/v1/".freeze

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
end
