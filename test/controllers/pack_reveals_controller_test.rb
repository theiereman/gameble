require "test_helper"
require_relative "../support/counting_rate_limit"
require_relative "../support/game_packs"
require_relative "../support/steam_sign_in"

# POST /:locale/packs/:token/reveal: the booster says how the player's latest
# capsule was revealed once its last card is face up. JSON in, 204 or a JSON
# refusal out.
class PackRevealsControllerTest < ActionDispatch::IntegrationTest
  include CountingRateLimit
  include GamePacks
  include SteamSignIn

  setup do
    @player = accounts_players(:player)
    @older = create_pack(@player, opened_at: 2.minutes.ago)
    @latest = create_pack(@player, opened_at: 1.minute.ago)
  end

  def reveal(mode, pack: @latest, token: pack.token, locale: :en)
    post pack_reveal_path(token, locale:), params: { mode: }.compact, as: :json
  end

  def modes = Game::Pack.where(player_id: @player.id).order(:id).pluck(:reveal_mode)

  def assert_json_error(status, code, message)
    assert_response status
    assert_equal({ "error" => { "code" => code, "message" => message } }, response.parsed_body)
  end

  test "the latest pack stores its mode: 204, no body, one event" do
    sign_in(@player)

    reveal("one_by_one")

    assert_response :no_content
    assert_empty response.body
    assert_equal "one_by_one", @latest.reload.reveal_mode
    assert_equal [ "one_by_one" ], game_events(@player, Game::PackRevealed).map { it.data[:mode] }
  end

  test "a repeat answers 204 and changes nothing" do
    sign_in(@player)
    reveal("all")

    assert_no_difference -> { Rails.configuration.event_store.read.count } do
      reveal("one_by_one")
    end
    assert_response :no_content
    assert_equal "all", @latest.reload.reveal_mode
  end

  test "an older opened pack is refused: 422 not_latest_pack" do
    sign_in(@player)

    assert_no_changes -> { modes } do
      reveal("all", pack: @older, locale: :fr)
    end
    assert_json_error :unprocessable_content, "not_latest_pack", I18n.t("errors.game.not_latest_pack", locale: :fr)
  end

  test "another player's, an unopened or an unknown pack is not found: 404 pack_not_found" do
    sign_in(@player)
    stranger = create_pack(accounts_players(:moderator), opened_at: Time.current)
    unopened = create_pack(@player)

    [ stranger.token, unopened.token, "1" * 24 ].each do |token|
      reveal("all", token:)
      assert_json_error :not_found, "pack_not_found", I18n.t("errors.game.pack_not_found", locale: :en)
    end
    assert_nil stranger.reload.reveal_mode
    assert_equal [ nil, nil, nil ], modes
  end

  [ nil, "fast", 1, [ "all" ] ].each do |mode|
    test "a mode of #{mode.inspect} writes nothing: 400 invalid_reveal_mode" do
      sign_in(@player)

      assert_no_changes -> { modes } do
        reveal(mode)
      end
      assert_json_error :bad_request, "invalid_reveal_mode", I18n.t("errors.game.invalid_reveal_mode", locale: :en)
    end
  end

  test "a visitor writes nothing: 401 sign_in_required" do
    assert_no_changes -> { modes } do
      reveal("all")
    end

    assert_json_error :unauthorized, "sign_in_required", I18n.t("authorization.sign_in_required", locale: :en)
  end

  test "a player banned since signing in is a visitor: 401" do
    sign_in(@player)
    @player.update_columns(banned_at: Time.current)

    reveal("all")

    assert_json_error :unauthorized, "sign_in_required", I18n.t("authorization.sign_in_required", locale: :en)
    assert_nil @latest.reload.reveal_mode
  end

  test "a reveal without the CSRF token is refused and writes nothing" do
    sign_in(@player)
    allowed = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = true

    reveal("all")

    assert_response :unprocessable_content
    assert_nil @latest.reload.reveal_mode
  ensure
    ActionController::Base.allow_forgery_protection = allowed
  end

  test "thirty reveals a minute are answered; the thirty-first is throttled with Retry-After" do
    sign_in(@player)

    with_counting_rate_limit(PackRevealsController) do
      30.times do
        reveal("all")
        assert_response :no_content
      end

      reveal("all")
      assert_json_error :too_many_requests, "throttled", I18n.t("pack_reveals.create.throttled", locale: :en)
      assert_equal "60", response.headers["Retry-After"]
    end
  end
end
