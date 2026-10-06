require "test_helper"
require_relative "../support/counting_rate_limit"
require_relative "../support/library_requests"

# POST /:locale/library/seen (AD-26, story 10.1): the collection page posts
# the latest gain it showed as new; the watermark keeps the greater value,
# never past now. JSON in, 204 or a JSON refusal out.
class CollectionSeenControllerTest < ActionDispatch::IntegrationTest
  include CountingRateLimit
  include LibraryRequests

  setup do
    OmniAuth.config.test_mode = true
    @player = accounts_players(:player)
  end

  teardown do
    OmniAuth.config.mock_auth.delete(:steam)
    OmniAuth.config.test_mode = false
  end

  def mark(up_to, locale: :en)
    post library_seen_path(locale:), params: { up_to: }.compact, as: :json
  end

  def watermark = Game::PlayerState.find_by(player_id: @player.id)&.collection_seen_up_to

  def assert_json_error(status, code, message)
    assert_response status
    assert_equal({ "error" => { "code" => code, "message" => message } }, response.parsed_body)
  end

  test "a player's time becomes their watermark, to the microsecond: 204, no body" do
    sign_in(@player)
    up_to = 1.hour.ago.change(usec: 123_456)

    mark(up_to.utc.iso8601(6))

    assert_response :no_content
    assert_empty response.body
    assert_equal up_to, watermark
  end

  test "an earlier time leaves the watermark; a later one moves it" do
    sign_in(@player)
    seen = 1.hour.ago.change(usec: 500_000)
    Game::PlayerState.where(player_id: @player.id).update_all(collection_seen_up_to: seen)

    mark(2.hours.ago.utc.iso8601(6))
    assert_response :no_content
    assert_equal seen, watermark

    mark(seen.change(usec: 500_001).utc.iso8601(6))
    assert_response :no_content
    assert_equal seen.change(usec: 500_001), watermark
  end

  test "a time in the future is stored as now" do
    sign_in(@player)

    freeze_time do
      mark(1.day.from_now.utc.iso8601(6))

      assert_response :no_content
      assert_equal Time.current, watermark
    end
  end

  test "a player without a state row gets one" do
    sign_in(@player)
    Game::PlayerState.where(player_id: @player.id).delete_all
    up_to = 1.minute.ago.change(usec: 1)

    mark(up_to.iso8601(6))

    assert_response :no_content
    assert_equal up_to, watermark
  end

  [ nil, "", "yesterday", "2026-13-45T99:00:00Z", 1_700_000_000 ].each do |up_to|
    test "an up_to of #{up_to.inspect} writes nothing: 422 invalid_time" do
      sign_in(@player)

      assert_no_changes -> { Game::PlayerState.find_by!(player_id: @player.id).attributes } do
        mark(up_to, locale: :fr)
      end
      assert_json_error :unprocessable_content, "invalid_time", I18n.t("errors.game.invalid_time", locale: :fr)
    end
  end

  test "a visitor writes nothing: 401 sign_in_required" do
    assert_no_changes -> { Game::PlayerState.pluck(:collection_seen_up_to) } do
      mark(1.minute.ago.iso8601(6))
    end

    assert_json_error :unauthorized, "sign_in_required", I18n.t("authorization.sign_in_required", locale: :en)
  end

  test "a player banned since signing in is a visitor: 401" do
    sign_in(@player)
    @player.update_columns(banned_at: Time.current)

    mark(1.minute.ago.iso8601(6))

    assert_json_error :unauthorized, "sign_in_required", I18n.t("authorization.sign_in_required", locale: :en)
    assert_nil watermark
  end

  test "thirty marks a minute are answered; the thirty-first is throttled with Retry-After" do
    sign_in(@player)

    with_counting_rate_limit(CollectionSeenController) do
      30.times do
        mark(1.minute.ago.iso8601(6))
        assert_response :no_content
      end

      mark(1.minute.ago.iso8601(6))
      assert_json_error :too_many_requests, "throttled", I18n.t("library.seen.throttled", locale: :en)
      assert_equal "60", response.headers["Retry-After"]
    end
  end
end
