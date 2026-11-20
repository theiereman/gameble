require "test_helper"
require_relative "../support/counting_rate_limit"
require_relative "../support/steam_sign_in"

# POST /:locale/exchanges/tab: the sub-tab bar keeps the sub-tab shown. JSON in, 204 or a JSON refusal out.
class ExchangeTabsControllerTest < ActionDispatch::IntegrationTest
  include CountingRateLimit
  include SteamSignIn

  setup do
    @player = accounts_players(:player)
  end

  def keep(tab, locale: :en)
    post exchanges_tab_path(locale:), params: { tab: }.compact, as: :json
  end

  def kept = Game::PlayerState.where(player_id: @player.id).pick(:exchanges_tab)

  def assert_json_error(status, code, message)
    assert_response status
    assert_equal({ "error" => { "code" => code, "message" => message } }, response.parsed_body)
  end

  test "a player's sub-tab is kept: 204, no body" do
    sign_in(@player)

    keep("friends")

    assert_response :no_content
    assert_empty response.body
    assert_equal "friends", kept
  end

  test "an unknown tab writes nothing: 422 unknown_tab" do
    sign_in(@player)

    keep("foo", locale: :fr)

    assert_json_error :unprocessable_content, "unknown_tab", "Cet onglet n'existe pas."
    assert_nil kept
  end

  test "a visitor writes nothing: 401 sign_in_required" do
    keep("market")

    assert_json_error :unauthorized, "sign_in_required", I18n.t("authorization.sign_in_required", locale: :en)
    assert_nil kept
  end

  test "thirty a minute are answered; the thirty-first is throttled with Retry-After" do
    sign_in(@player)

    with_counting_rate_limit(ExchangeTabsController) do
      30.times do |index|
        keep(index.even? ? "market" : "friends")
        assert_response :no_content
      end

      keep("market")
      assert_json_error :too_many_requests, "throttled", "Too many changes in a minute. Try again in a moment."
      assert_equal "60", response.headers["Retry-After"]
    end
  end
end
