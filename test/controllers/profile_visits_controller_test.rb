require "test_helper"
require_relative "../support/counting_rate_limit"
require_relative "../support/steam_sign_in"

# POST /:locale/brothers/:token/visit: 204 when counted or already counted this hour, 404 for a profile the viewer may not see.
class ProfileVisitsControllerTest < ActionDispatch::IntegrationTest
  include CountingRateLimit
  include SteamSignIn

  setup do
    @viewer = accounts_players(:player)
    @owner = accounts_players(:moderator)
    @owner.update!(visibility: :public)
  end

  def visit(owner = @owner) = post(profile_visit_path(token: owner.token, locale: :en))

  test "a visit is written: 204 and no body" do
    sign_in(@viewer)

    assert_difference -> { Game::ProfileVisit.count }, 1 do
      visit
    end

    assert_response :no_content
    assert_empty response.body
  end

  test "a repeat within the hour answers 204 and writes nothing" do
    sign_in(@viewer)
    visit

    assert_no_difference -> { Game::ProfileVisit.count } do
      visit
    end

    assert_response :no_content
  end

  test "a private profile is 404, nothing written" do
    @owner.update!(visibility: :private)
    sign_in(@viewer)

    assert_no_difference -> { Game::ProfileVisit.count } do
      visit
    end

    assert_response :not_found
  end

  test "a visitor writes nothing" do
    assert_no_difference -> { Game::ProfileVisit.count } do
      visit
    end

    assert_not response.successful?
  end

  test "the profile page carries the beacon for another player only" do
    sign_in(@viewer)

    get brother_path(token: @owner.token, locale: :en)
    assert_select "[data-controller=beacon][data-beacon-url-value=?]", profile_visit_path(token: @owner.token, locale: :en)

    get brother_path(token: @viewer.token, locale: :en)
    assert_select "[data-controller=beacon]", 0
  end

  test "a visitor's profile page has no beacon" do
    get brother_path(token: @owner.token, locale: :en)

    assert_select "[data-controller=beacon]", 0
  end

  test "sixty visits a minute are answered; the sixty-first is throttled" do
    sign_in(@viewer)

    with_counting_rate_limit(ProfileVisitsController) do
      60.times { visit and assert_response :no_content }
      visit

      assert_response :too_many_requests
    end
  end
end
