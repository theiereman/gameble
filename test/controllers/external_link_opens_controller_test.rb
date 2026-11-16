require "test_helper"
require_relative "../support/counting_rate_limit"
require_relative "../support/steam_sign_in"

# POST /:locale/links/:link/opened: the first click on the source code or support link; 204, 404 for an unknown link.
class ExternalLinkOpensControllerTest < ActionDispatch::IntegrationTest
  include CountingRateLimit
  include SteamSignIn

  setup { @player = accounts_players(:player) }

  def open_link(link) = post(link_open_path(link:, locale: :en))

  test "the first click is written: 204 and no body" do
    sign_in(@player)

    open_link("support")

    assert_response :no_content
    assert_empty response.body
    assert_not_nil Game::PlayerState.find_by!(player_id: @player.id).support_opened_at
  end

  test "an unknown link is 404, nothing written" do
    sign_in(@player)

    open_link("other")

    assert_response :not_found
    assert_nil Game::PlayerState.find_by(player_id: @player.id)&.source_code_opened_at
    assert_nil Game::PlayerState.find_by(player_id: @player.id)&.support_opened_at
  end

  test "a visitor writes nothing" do
    assert_no_difference -> { Game::PlayerState.count } do
      open_link("support")
    end

    assert_not response.successful?
  end

  test "sixty clicks a minute are answered; the sixty-first is throttled" do
    sign_in(@player)

    with_counting_rate_limit(ExternalLinkOpensController) do
      60.times { open_link("support") and assert_response :no_content }
      open_link("support")

      assert_response :too_many_requests
    end
  end
end
