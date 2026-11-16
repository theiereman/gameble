require "test_helper"
require_relative "../support/counting_rate_limit"
require_relative "../support/steam_sign_in"

# POST /:locale/bell/read: the bell posts the keys of the lines the player read,
# so every other device hides them too; 204 and no body, 422 for bad keys.
class BellReadsControllerTest < ActionDispatch::IntegrationTest
  include CountingRateLimit
  include SteamSignIn

  setup do
    @hugo = accounts_players(:player)
  end

  def mark(keys = [ "trade:abc:1" ]) = post(bell_read_path(locale: :en), params: { keys: }, as: :json)

  test "the keys are remembered for the player: 204, no body" do
    sign_in(@hugo)

    mark([ "trade:abc:1", "mission:2026-11-16" ])

    assert_response :no_content
    assert_empty response.body
    assert_equal Set.new([ "trade:abc:1", "mission:2026-11-16" ]), Game::BellReadKeys.call(@hugo)
  end

  test "malformed keys are refused and nothing is written" do
    sign_in(@hugo)

    assert_no_difference -> { Game::BellRead.count } do
      mark([ "<b>" ])
      assert_response :unprocessable_content
      post bell_read_path(locale: :en), params: { keys: "trade:abc:1" }, as: :json
      assert_response :unprocessable_content
    end
  end

  test "a visitor writes nothing" do
    assert_no_difference -> { Game::BellRead.count } do
      mark
    end

    assert_not response.successful?
  end

  test "sixty marks a minute are answered; the sixty-first is throttled" do
    sign_in(@hugo)

    with_counting_rate_limit(BellReadsController) do
      60.times { mark and assert_response :no_content }
      mark

      assert_response :too_many_requests
      assert_equal "60", response.headers["Retry-After"]
    end
  end
end
