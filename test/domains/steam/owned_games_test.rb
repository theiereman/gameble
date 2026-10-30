require "test_helper"
require_relative "../../support/steam_api_stubs"
require_relative "../../support/catalog_seeds"

class Steam::OwnedGamesTest < ActiveSupport::TestCase
  include SteamApiStubs
  include CatalogSeeds

  STEAM_ID = "76561197960287930".freeze
  PORTAL_APPID, RARE_APPID, DRAFT_ONLY_APPID, UNKNOWN_APPID = 400, 403, 500, 999

  setup do
    stub_steam_api
    catalog_cards(:portal).update_column(:source_key, Steam::CardMapping.source_key(PORTAL_APPID))
    catalog_cards(:rare_card).update_column(:source_key, Steam::CardMapping.source_key(RARE_APPID))
    draft_season = seed_card_seasons([ 0.5 ], prefix: "draft-only")
    draft_only = Catalog::CardSeason.find_by!(season: draft_season)
    draft_only.update!(rarity: :rare, number: 1)
    draft_only.card.update_column(:source_key, Steam::CardMapping.source_key(DRAFT_ONLY_APPID))
  end

  teardown { unstub_steam_api }

  def owned_games
    Steam::OwnedGames.call(steam_id: STEAM_ID)
  end

  test "a public library gives the card ids of its published catalog games, sorted" do
    calls = stub_owned_games([ RARE_APPID, DRAFT_ONLY_APPID, UNKNOWN_APPID, PORTAL_APPID ])

    assert_equal Dry::Monads::Success([ catalog_cards(:portal).id, catalog_cards(:rare_card).id ].sort), owned_games
    assert_equal 1, calls.size
  end

  test "a library listing a game twice gives its card once" do
    stub_owned_games([ PORTAL_APPID, PORTAL_APPID ])

    assert_equal Dry::Monads::Success([ catalog_cards(:portal).id ]), owned_games
  end

  test "a library of games outside the catalog or only in a draft season gives no card" do
    stub_owned_games([ DRAFT_ONLY_APPID, UNKNOWN_APPID ])

    assert_equal Dry::Monads::Success([]), owned_games
  end

  test "an explicitly empty library gives no card" do
    stub_owned_games([])

    assert_equal Dry::Monads::Success([]), owned_games
  end

  test "malformed entries are skipped" do
    stub_owned_games_response({ "game_count" => 4, "games" => [ "junk", { "appid" => "x" }, { "appid" => 2**31 }, { "appid" => PORTAL_APPID } ] })

    assert_equal Dry::Monads::Success([ catalog_cards(:portal).id ]), owned_games
  end

  test "a listed library with no readable appid raises, never succeeding empty" do
    stub_owned_games_response({ "game_count" => 2, "games" => [ {}, { "app_id" => PORTAL_APPID } ] })

    error = assert_raises(Steam::WebApi::Error) { owned_games }
    assert_not_kind_of Steam::WebApi::Unavailable, error
  end

  [ nil, 12 ].each do |game_count|
    test "a private library fails as private, not as an empty library (game count #{game_count.inspect})" do
      stub_private_owned_games(game_count:)

      assert_equal Dry::Monads::Failure(:library_private), owned_games
    end
  end

  [ 408, 429, 500, 502, 503, 504, :timeout, :connection_failed, :ssl_error ].each do |failure|
    test "Steam failing with #{failure} fails as unavailable after one call" do
      calls = stub_owned_games_failure(failure)

      assert_equal Dry::Monads::Failure(:steam_unavailable), owned_games
      assert_equal 1, calls.size
    end
  end

  [ 401, 403 ].each do |status|
    test "a key Steam rejects (#{status}) raises a broken key" do
      stub_owned_games_failure(status)

      error = assert_raises(Steam::WebApi::BrokenKey) { owned_games }
      assert_not_includes error.message, API_KEY
    end
  end

  test "a missing key raises a broken key without calling Steam" do
    Rails.configuration.x.steam.api_key = nil
    calls = stub_owned_games([ PORTAL_APPID ])

    assert_raises(Steam::WebApi::BrokenKey) { owned_games }
    assert_empty calls
  end

  [ "{}", { "response" => [] }.to_json, { "response" => { "games" => {} } }.to_json ].each do |body|
    test "a malformed answer raises (#{body})" do
      steam_stubs.get(OWNED_GAMES_PATH) { [ 200, { "Content-Type" => "application/json" }, body ] }

      error = assert_raises(Steam::WebApi::Error) { owned_games }
      assert_not_kind_of Steam::WebApi::Unavailable, error
      assert_not_includes error.message, API_KEY
    end
  end
end
