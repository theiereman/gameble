require "test_helper"
require_relative "../support/game_packs"
require_relative "../support/steam_sign_in"

class DataExportsControllerTest < ActionDispatch::IntegrationTest
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
    assert_equal Time.utc(2026, 10, 14, 9, 30), @player.reload.last_exported_at
  end

  test "the last export's file downloads again later, and nobody else's" do
    sign_in(@player)
    travel_to Time.utc(2026, 10, 14, 9, 30) do
      post settings_export_path(locale: :en), headers: json_headers
    end
    exported = response.body

    travel_to Time.utc(2026, 10, 20, 12) do
      get settings_export_path(locale: :fr)
    end

    assert_response :success
    assert_equal "application/json", response.media_type
    assert_match(/\Aattachment; filename="gameble-export-2026-10-14\.json"/, response.headers["Content-Disposition"])
    assert_equal exported, response.body

    sign_in(accounts_players(:moderator))
    get settings_export_path(locale: :fr)
    assert_response :not_found
  end

  test "the export's own file gives the time of the export before it" do
    Accounts::RecordExport.new.call(player: @player, at: Time.utc(2026, 10, 1, 8), file: "{}").value!
    sign_in(@player)

    post settings_export_path(locale: :en), headers: json_headers

    assert_equal "2026-10-01T08:00:00Z", response.parsed_body.dig("profile", "lastExportedAt")
  end

  test "the settings' script asks in JSON and gets the same file" do
    sign_in(@player)

    post settings_export_path(locale: :en), headers: json_headers

    assert_response :success
    assert_match(/\Aattachment; filename="gameble-export-\d{4}-\d{2}-\d{2}\.json"/, response.headers["Content-Disposition"])
    assert_equal [], response.parsed_body["collection"]
  end

  test "a second export within five minutes of the last is refused: 429 in JSON with the next allowed time, an alert in HTML" do
    sign_in(@player)
    message = ->(locale) { I18n.t("errors.accounts.export_too_soon", locale:) }

    travel_to Time.utc(2026, 10, 14, 9, 30) do
      post settings_export_path(locale: :en), headers: json_headers
      assert_response :success
    end

    travel_to Time.utc(2026, 10, 14, 9, 32) do
      post settings_export_path(locale: :en), headers: json_headers
      assert_response :too_many_requests
      assert_equal "180", response.headers["Retry-After"]
      assert_equal({ "error" => { "code" => "export_too_soon", "message" => message.(:en), "nextExportAt" => "2026-10-14T09:35:00Z" } },
        response.parsed_body)

      post settings_export_path(locale: :fr)
      assert_redirected_to settings_path(locale: :fr)
      assert_response :see_other
      assert_equal message.(:fr), flash[:alert]
    end
    assert_equal Time.utc(2026, 10, 14, 9, 30), @player.reload.last_exported_at

    travel_to Time.utc(2026, 10, 14, 9, 35) do
      post settings_export_path(locale: :en), headers: json_headers
      assert_response :success
    end
  end

  test "a visitor is refused like any player-only action" do
    post settings_export_path(locale: :fr)
    assert_redirected_to home_path(locale: :fr)
    assert_nil flash[:alert]

    post settings_export_path(locale: :en), headers: json_headers
    assert_response :unauthorized
    assert_equal "sign_in_required", response.parsed_body.dig("error", "code")
  end

  test "a visitor cannot download an export" do
    get settings_export_path(locale: :fr)
    assert_redirected_to home_path(locale: :fr)
  end
end
