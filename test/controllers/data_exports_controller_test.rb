require "test_helper"
require_relative "../support/counting_rate_limit"
require_relative "../support/game_packs"
require_relative "../support/steam_sign_in"

class DataExportsControllerTest < ActionDispatch::IntegrationTest
  include CountingRateLimit
  include GamePacks
  include SteamSignIn

  setup do
    @player = accounts_players(:player)
  end

  def json_headers = { "Accept" => "application/json" }

  test "the export is the player's data as a JSON attachment named by the day" do
    create_pack(@player, cards: Array.new(5, catalog_card_seasons(:portal_one).id))
    Game::OpenPack.new.call(player: @player).value!
    sign_in(@player)

    travel_to Time.utc(2026, 10, 14, 9, 30) do
      post settings_export_path(locale: :fr)
    end

    assert_response :success
    assert_equal "application/json", response.media_type
    assert_match(/\Aattachment; filename="gameble-export-2026-10-14\.json"/, response.headers["Content-Disposition"])
    body = response.parsed_body
    assert_equal "76561197960287001", body.dig("profile", "steamId")
    assert_equal [ [ "portal", 1, "Portal", 5 ] ], body["collection"].map { it.values_at("slug", "season", "title", "quantity") }
  end

  test "the settings' script asks in JSON and gets the same file" do
    sign_in(@player)

    post settings_export_path(locale: :en), headers: json_headers

    assert_response :success
    assert_match(/\Aattachment; filename="gameble-export-\d{4}-\d{2}-\d{2}\.json"/, response.headers["Content-Disposition"])
    assert_equal [], response.parsed_body["collection"]
  end

  test "a second export within five minutes is refused: 429 in JSON, the settings with an alert in HTML" do
    sign_in(@player)

    with_counting_rate_limit(DataExportsController) do
      post settings_export_path(locale: :en), headers: json_headers
      assert_response :success

      post settings_export_path(locale: :en), headers: json_headers
      assert_response :too_many_requests
      assert_equal "300", response.headers["Retry-After"]
      assert_equal({ "error" => { "code" => "throttled", "message" => I18n.t("data_exports.create.throttled", locale: :en) } },
        response.parsed_body)

      post settings_export_path(locale: :fr)
      assert_redirected_to settings_path(locale: :fr)
      assert_response :see_other
      assert_equal I18n.t("data_exports.create.throttled", locale: :fr), flash[:alert]
    end
  end

  test "a visitor is refused like any player-only action" do
    post settings_export_path(locale: :fr)
    assert_redirected_to home_path(locale: :fr)
    assert_equal I18n.t("authorization.sign_in_required", locale: :fr), flash[:alert]

    post settings_export_path(locale: :en), headers: json_headers
    assert_response :unauthorized
    assert_equal "sign_in_required", response.parsed_body.dig("error", "code")
  end

  test "the export is a POST: there is no GET" do
    sign_in(@player)

    get "/fr/settings/export"

    assert_response :not_found
  end
end
