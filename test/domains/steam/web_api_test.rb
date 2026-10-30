require "test_helper"
require_relative "../../support/steam_api_stubs"

class Steam::WebApiTest < ActiveSupport::TestCase
  include SteamApiStubs

  setup { stub_steam_api }
  teardown { unstub_steam_api }

  test "a page of the app list asks for games only, with the key, after the cursor" do
    seen = nil
    steam_stubs.get(APP_LIST_PATH) do |env|
      seen = env.params
      [ 200, { "Content-Type" => "application/json" }, { "response" => { "apps" => [ { "appid" => 10, "name" => "Counter-Strike", "last_modified" => 1_700_000_000, "price_change_number" => 7 } ], "have_more_results" => true, "last_appid" => 10 } }.to_json ]
    end

    page = Steam::WebApi.new.get_app_list(last_appid: 5, max_results: 100)

    assert_equal({ "include_games" => "true", "last_appid" => "5", "max_results" => "100", "key" => API_KEY }, seen)
    assert_equal [ { appid: 10, name: "Counter-Strike", last_modified: Time.at(1_700_000_000).utc, price_change_number: 7 } ], page.apps
    assert page.have_more_results
    assert_equal 10, page.last_appid
  end

  test "the last page has no more results" do
    stub_app_list_page(after: 0, appids: [ 1, 2 ], more: false)

    page = Steam::WebApi.new.get_app_list(last_appid: 0, max_results: 100)

    assert_equal [ 1, 2 ], page.apps.map { |app| app[:appid] }
    assert_not page.have_more_results
    assert_nil page.last_appid
  end

  test "an entry without a valid appid is dropped and counted; a kept entry's malformed fields are left empty" do
    entries = [ {}, { "appid" => "x" }, { "appid" => -3 }, "junk", { "appid" => 2**40 }, { "appid" => 0 }, { "appid" => 1.5 },
      { "appid" => 10, "name" => "Ok", "last_modified" => 1_700_000_000, "price_change_number" => 7 },
      { "appid" => "20", "name" => [ "x" ], "last_modified" => [ 1 ], "price_change_number" => "12x" },
      { "appid" => 30, "name" => "N\u0000ul", "last_modified" => 253_402_300_800, "price_change_number" => -1 } ]
    steam_stubs.get(APP_LIST_PATH) do
      [ 200, { "Content-Type" => "application/json" }, { "response" => { "apps" => entries, "have_more_results" => true, "last_appid" => [ 30 ] } }.to_json ]
    end

    page = Steam::WebApi.new.get_app_list(last_appid: 0, max_results: 100)

    assert_equal 7, page.malformed
    assert_equal [
      { appid: 10, name: "Ok", last_modified: Time.at(1_700_000_000).utc, price_change_number: 7 },
      { appid: 20, name: "", last_modified: nil, price_change_number: nil },
      { appid: 30, name: "Nul", last_modified: nil, price_change_number: nil }
    ], page.apps
    assert_nil page.last_appid, "a malformed cursor is left out; the page goes on from its highest appid"
  end

  test "a page of malformed entries only, with more to come and no valid cursor, raises without the key" do
    steam_stubs.get(APP_LIST_PATH) do
      [ 200, { "Content-Type" => "application/json" }, { "response" => { "apps" => [ {}, "junk" ], "have_more_results" => true, "last_appid" => "x" } }.to_json ]
    end

    error = assert_raises(Steam::WebApi::Error) { Steam::WebApi.new.get_app_list(last_appid: 0, max_results: 100) }
    assert_not_includes error.message, API_KEY
  end

  test "a page of malformed entries only goes on with a valid cursor, and ends the list without more to come" do
    [ { "have_more_results" => true, "last_appid" => 50 }, {} ].each do |extra|
      steam_stubs.clear
      steam_stubs.get(APP_LIST_PATH) do
        [ 200, { "Content-Type" => "application/json" }, { "response" => { "apps" => [ {}, "junk" ] }.merge(extra) }.to_json ]
      end

      page = Steam::WebApi.new.get_app_list(last_appid: 0, max_results: 100)

      assert_equal [ [], 2, extra["last_appid"] ], [ page.apps, page.malformed, page.last_appid ], extra.inspect
    end
  end

  test "an empty page with more to come and no cursor does not raise" do
    steam_stubs.get(APP_LIST_PATH) do
      [ 200, { "Content-Type" => "application/json" }, { "response" => { "apps" => [], "have_more_results" => true } }.to_json ]
    end

    assert_empty Steam::WebApi.new.get_app_list(last_appid: 0, max_results: 100).apps
  end

  test "a well-formed page counts no malformed entry" do
    stub_app_list_page(after: 0, appids: [ 1, 2 ], more: true)

    assert_equal 0, Steam::WebApi.new.get_app_list(last_appid: 0, max_results: 100).malformed
  end

  test "a 429 then a 503 are retried until the page comes" do
    stub_app_list_status(429, after: 0)
    stub_app_list_status(503, after: 0)
    stub_app_list_page(after: 0, appids: [ 3 ], more: false)

    page = Steam::WebApi.new.get_app_list(last_appid: 0, max_results: 100)

    assert_equal [ 3 ], page.apps.map { |app| app[:appid] }
  end

  [ 429, 500, 502 ].each do |status|
    test "a #{status} that outlasts the retries raises an error without the key" do
      calls = 0
      steam_stubs.get(APP_LIST_PATH) do
        calls += 1
        [ status, {}, "" ]
      end

      error = assert_raises(Steam::WebApi::Error) { Steam::WebApi.new.get_app_list(last_appid: 0, max_results: 100) }

      assert_equal 5, calls
      assert_includes error.message, status.to_s
      assert_includes error.message, Steam::WebApi::REDACTED
      assert_not_includes error.message, API_KEY
      assert_nil error.cause
      assert_not_includes error.full_message, API_KEY
    end
  end

  test "a 403 is not retried and raises a broken key without the key" do
    calls = 0
    steam_stubs.get(APP_LIST_PATH) do
      calls += 1
      [ 403, {}, "" ]
    end

    error = assert_raises(Steam::WebApi::BrokenKey) { Steam::WebApi.new.get_app_list(last_appid: 0, max_results: 100) }

    assert_equal 1, calls
    assert_not_includes error.message, API_KEY
  end

  test "a connection failure raises an error without the key" do
    steam_stubs.get(APP_LIST_PATH) { raise Faraday::ConnectionFailed, "failed to open https://api.steampowered.com/?key=#{API_KEY}" }

    error = assert_raises(Steam::WebApi::Error) { Steam::WebApi.new.get_app_list(last_appid: 0, max_results: 100) }

    assert_not_includes error.message, API_KEY
    assert_nil error.cause
  end

  test "a missing key raises a broken key before any call" do
    error = assert_raises(Steam::WebApi::BrokenKey) { Steam::WebApi.new(api_key: nil).get_app_list(last_appid: 0, max_results: 100) }

    assert_equal "STEAM_API_KEY is not set", error.message
  end

  test "the key does not show in an inspection" do
    assert_not_includes Steam::WebApi.new.inspect, API_KEY
  end

  test "redact replaces the key in plain and URL-encoded forms" do
    api = Steam::WebApi.new(api_key: "a+b/c")

    assert_equal "x [FILTERED] y [FILTERED]", api.redact("x a+b/c y a%2Bb%2Fc")
  end

  [ "not json", "{}", { "response" => [] }.to_json, { "response" => { "apps" => {} } }.to_json ].each do |body|
    test "an answer without a response object or an app list raises (#{body})" do
      steam_stubs.get(APP_LIST_PATH) { [ 200, { "Content-Type" => "application/json" }, body ] }

      assert_raises(Steam::WebApi::Error) { Steam::WebApi.new.get_app_list(last_appid: 0, max_results: 100) }
    end
  end

  # GetItems

  def get_items(appids = [ 10, 20 ])
    Steam::WebApi.new.get_items(appids: appids, context: { language: "english", country_code: "US" }, data_request: { include_reviews: true })
  end

  test "get_items asks for the appids with the context and the data request, with the key" do
    seen = nil
    steam_stubs.get(ITEMS_PATH) do |env|
      seen = env.params
      [ 200, { "Content-Type" => "application/json" }, { "response" => { "store_items" => [ reviewed_item(10, 812) ] } }.to_json ]
    end

    get_items

    assert_equal %w[input_json key], seen.keys.sort
    assert_equal API_KEY, seen["key"]
    assert_equal({ "ids" => [ { "appid" => 10 }, { "appid" => 20 } ], "context" => { "language" => "english", "country_code" => "US" }, "data_request" => { "include_reviews" => true } },
      JSON.parse(seen["input_json"]))
  end

  test "get_items returns the raw store items keyed by the requested appids" do
    stub_get_items(10 => reviewed_item(10, 812), 20 => unavailable_item(20), 30 => reviewed_item(30, 1))

    items = get_items([ 10, 20, 40 ])

    assert_equal [ 10, 20 ], items.keys
    assert_equal reviewed_item(10, 812), items[10]
    assert_equal 2, items[20]["success"]
  end

  test "get_items skips an item that is not an object or whose appid is not an integer" do
    items = [ "junk", [ 10 ], { "appid" => [ 10 ], "success" => 1 }, { "appid" => "10x", "success" => 1 }, { "appid" => 10.0, "success" => 1 },
      { "id" => { "a" => 1 }, "success" => 1 }, { "appid" => "20", "success" => 1 } ]
    steam_stubs.get(ITEMS_PATH) { [ 200, { "Content-Type" => "application/json" }, { "response" => { "store_items" => items } }.to_json ] }

    assert_equal({ 20 => { "appid" => "20", "success" => 1 } }, get_items([ 10, 20 ]))
  end

  test "get_items is retried on a 429 and raises without the key once retries are spent" do
    calls = 0
    steam_stubs.get(ITEMS_PATH) do
      calls += 1
      [ 429, {}, "" ]
    end

    error = assert_raises(Steam::WebApi::Error) { get_items }

    assert_equal 5, calls
    assert_includes error.message, "429"
    assert_not_includes error.message, API_KEY
    assert_nil error.cause
  end

  [ "not json", "{}", { "response" => [] }.to_json, { "response" => {} }.to_json, { "response" => { "store_items" => {} } }.to_json,
    { "response" => { "store_items" => [] } }.to_json ].each do |body|
    test "get_items raises on a malformed or empty answer (#{body})" do
      steam_stubs.get(ITEMS_PATH) { [ 200, { "Content-Type" => "application/json" }, body ] }

      error = assert_raises(Steam::WebApi::Error) { get_items }
      assert_not_includes error.message, API_KEY
    end
  end

  # GetTagList

  test "get_tag_list asks for the tags in the language, with the key, and returns them named" do
    calls = stub_get_tag_list(19 => "Action", 492 => " Indie ")

    tags = Steam::WebApi.new.get_tag_list(language: "english")

    assert_equal [ { "language" => "english", "key" => API_KEY } ], calls
    assert_equal [ { tagid: 19, name: "Action" }, { tagid: 492, name: "Indie" } ], tags
  end

  [ "not json", "{}", { "response" => [] }.to_json, { "response" => {} }.to_json, { "response" => { "tags" => {} } }.to_json,
    { "response" => { "tags" => [] } }.to_json, { "response" => { "tags" => [ { "tagid" => "x" }, { "name" => "Action" } ] } }.to_json ].each do |body|
    test "get_tag_list raises on a malformed or empty answer (#{body})" do
      steam_stubs.get(TAG_LIST_PATH) { [ 200, { "Content-Type" => "application/json" }, body ] }

      error = assert_raises(Steam::WebApi::Error) { Steam::WebApi.new.get_tag_list(language: "english") }
      assert_not_includes error.message, API_KEY
    end
  end

  # GetPlayerSummaries

  STEAM_ID = "76561197960287930".freeze

  def player_summary(steamid = STEAM_ID)
    Steam::WebApi.new.get_player_summary(steamid:)
  end

  def answer_players(players)
    steam_stubs.get(PLAYER_SUMMARIES_PATH) { [ 200, { "Content-Type" => "application/json" }, { "response" => { "players" => players } }.to_json ] }
  end

  test "get_player_summary asks for the player with the key and returns their persona name, stripped" do
    calls = stub_player_summary(STEAM_ID, "  Gabe the Brave ")

    assert_equal "Gabe the Brave", player_summary
    assert_equal [ { "steamids" => STEAM_ID, "key" => API_KEY } ], calls
  end

  test "get_player_summary answers nil when Steam knows no such player" do
    stub_player_summary(STEAM_ID, nil)

    assert_nil player_summary
  end

  [ "", "   " ].each do |name|
    test "get_player_summary answers nil for an empty name (#{name.inspect})" do
      stub_player_summary(STEAM_ID, name)

      assert_nil player_summary
    end
  end

  test "get_player_summary reads only the player asked about" do
    answer_players([ { "steamid" => "76561197960287931", "personaname" => "Someone else" } ])

    assert_nil player_summary
  end

  test "get_player_summary makes one attempt, without retry, and raises without the key" do
    calls = stub_player_summary_failure(503)

    error = assert_raises(Steam::WebApi::Error) { player_summary }

    assert_equal 1, calls.size
    assert_includes error.message, "503"
    assert_not_includes error.message, API_KEY
    assert_nil error.cause
  end

  test "get_player_summary raises without the key on a connection failure" do
    stub_player_summary_failure(:connection_failed)

    error = assert_raises(Steam::WebApi::Error) { player_summary }

    assert_not_includes error.message, API_KEY
    assert_includes error.message, Steam::WebApi::REDACTED
    assert_nil error.cause
  end

  test "get_player_summary waits five seconds at most, in all" do
    assert_equal 5.0, Steam::WebApi.player_summary_deadline
  end

  test "get_player_summary ends at its deadline when Steam is slow to connect and to answer, each under it" do
    Steam::WebApi.player_summary_deadline = 0.1
    phases = stub_slow_player_summary(STEAM_ID, "Gabe", connect: 0.08, answer: 0.08)

    error = assert_raises(Steam::WebApi::Error) { player_summary }

    assert_not_includes phases, :answered
    assert_not_kind_of Steam::WebApi::BrokenKey, error
    assert_includes error.message, "Faraday::TimeoutError"
    assert_not_includes error.message, API_KEY
    assert_nil error.cause
  end

  test "get_player_summary returns the name when Steam answers before the deadline" do
    Steam::WebApi.player_summary_deadline = 1
    stub_slow_player_summary(STEAM_ID, "Gabe", connect: 0.01, answer: 0.01)

    assert_equal "Gabe", player_summary
  end

  [ 401, 403 ].each do |status|
    test "get_player_summary raises a broken key, without the key, when Steam rejects it (#{status})" do
      calls = stub_player_summary_failure(status)

      error = assert_raises(Steam::WebApi::BrokenKey) { player_summary }

      assert_equal 1, calls.size
      assert_includes error.message, status.to_s
      assert_not_includes error.message, API_KEY
      assert_nil error.cause
    end
  end

  test "get_player_summary raises a broken key, calling no one, when no key is set" do
    Rails.configuration.x.steam.api_key = nil
    calls = stub_player_summary(STEAM_ID, "Gabe")

    assert_raises(Steam::WebApi::BrokenKey) { player_summary }
    assert_empty calls
  end

  [ "not json", "{}", { "response" => [] }.to_json, { "response" => {} }.to_json, { "response" => { "players" => {} } }.to_json,
    { "response" => { "players" => [ { "steamid" => STEAM_ID, "personaname" => 42 } ] } }.to_json ].each do |body|
    test "get_player_summary raises on a malformed answer (#{body})" do
      steam_stubs.get(PLAYER_SUMMARIES_PATH) { [ 200, { "Content-Type" => "application/json" }, body ] }

      error = assert_raises(Steam::WebApi::Error) { player_summary }
      assert_not_includes error.message, API_KEY
    end
  end

  # GetOwnedGames

  def owned_games(steamid = STEAM_ID)
    Steam::WebApi.new.get_owned_games(steamid:)
  end

  test "get_owned_games asks for the player's games, free ones and unvetted ones included, without app info, with the key" do
    calls = stub_owned_games([ 10 ])

    owned_games

    assert_equal [ { "steamid" => STEAM_ID, "include_appinfo" => "false", "include_played_free_games" => "true",
      "skip_unvetted_apps" => "false", "key" => API_KEY } ], calls
  end

  test "get_owned_games returns the appids of the owned games" do
    stub_owned_games([ 10, 440, 570 ])

    assert_equal [ 10, 440, 570 ], owned_games
  end

  test "get_owned_games returns an empty list when Steam lists no game" do
    stub_owned_games([])

    assert_equal [], owned_games
  end

  [ nil, 12 ].each do |game_count|
    test "get_owned_games answers nil for a private library (game count #{game_count.inspect})" do
      stub_private_owned_games(game_count:)

      assert_nil owned_games
    end
  end

  test "get_owned_games skips an entry that is not an object or whose appid is not a positive int4" do
    games = [ "junk", [ 10 ], {}, { "appid" => "x" }, { "appid" => 0 }, { "appid" => -3 }, { "appid" => 2**31 }, { "appid" => 1.5 },
      { "appid" => 20 }, { "appid" => "30" } ]
    stub_owned_games_response({ "game_count" => games.size, "games" => games })

    assert_equal [ 20, 30 ], owned_games
  end

  test "get_owned_games raises, without the key, when no listed game has a readable appid" do
    stub_owned_games_response({ "game_count" => 2, "games" => [ {}, { "app_id" => 10 } ] })

    error = assert_raises(Steam::WebApi::Error) { owned_games }

    assert_not_kind_of Steam::WebApi::Unavailable, error
    assert_not_includes error.message, API_KEY
  end

  [ 408, 429, 500, 502, 503, 504, :timeout, :connection_failed, :ssl_error ].each do |failure|
    test "get_owned_games makes one attempt and raises unavailable, without the key, on #{failure}" do
      calls = stub_owned_games_failure(failure)

      error = assert_raises(Steam::WebApi::Unavailable) { owned_games }

      assert_equal 1, calls.size
      assert_not_includes error.message, API_KEY
      assert_not_includes error.full_message, API_KEY
      assert_nil error.cause
    end
  end

  test "get_owned_games waits ten seconds at most, in all" do
    assert_equal 10.0, Steam::WebApi.owned_games_deadline
  end

  test "get_owned_games raises unavailable at its deadline when Steam is slow" do
    Steam::WebApi.owned_games_deadline = 0.05
    answered = false
    steam_stubs.get(OWNED_GAMES_PATH) do
      sleep 0.2
      answered = true
      [ 200, { "Content-Type" => "application/json" }, { "response" => { "games" => [] } }.to_json ]
    end

    error = assert_raises(Steam::WebApi::Unavailable) { owned_games }

    assert_not answered
    assert_includes error.message, "Faraday::TimeoutError"
  end

  [ 401, 403 ].each do |status|
    test "get_owned_games raises a broken key, without the key, when Steam rejects it (#{status})" do
      calls = stub_owned_games_failure(status)

      error = assert_raises(Steam::WebApi::BrokenKey) { owned_games }

      assert_equal 1, calls.size
      assert_not_includes error.message, API_KEY
    end
  end

  test "get_owned_games raises a broken key, calling no one, when no key is set" do
    Rails.configuration.x.steam.api_key = nil
    calls = stub_owned_games([ 10 ])

    assert_raises(Steam::WebApi::BrokenKey) { owned_games }
    assert_empty calls
  end

  [ "not json", "{}", { "response" => [] }.to_json, { "response" => { "games" => {} } }.to_json,
    { "response" => { "games" => nil } }.to_json ].each do |body|
    test "get_owned_games raises on a malformed answer (#{body})" do
      steam_stubs.get(OWNED_GAMES_PATH) { [ 200, { "Content-Type" => "application/json" }, body ] }

      error = assert_raises(Steam::WebApi::Error) { owned_games }
      assert_not_kind_of Steam::WebApi::Unavailable, error
      assert_not_includes error.message, API_KEY
    end
  end
end
