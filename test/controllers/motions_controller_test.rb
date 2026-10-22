require "test_helper"
require_relative "../support/steam_sign_in"

class MotionsControllerTest < ActionDispatch::IntegrationTest
  include SteamSignIn

  test "a visitor switching animations down gets the reduced form from the next load, in a cookie that lasts a year" do
    post motion_path(locale: :fr), params: { reduced: "on" }

    assert_redirected_to home_path(locale: :fr)
    assert_response :see_other
    assert_equal "reduced", cookies[:motion]
    assert_match(/motion=reduced.*HttpOnly.*SameSite=Lax/im, Array(response.headers["Set-Cookie"]).join("\n"))

    follow_redirect!
    assert_select "html[data-motion=reduced]"
    assert_select "button.motion-switch[aria-pressed=true]", text: "Animations réduites"
    assert_select "meta[name=view-transition]", 0
  end

  test "switching it off removes the cookie and the switch is not pressed" do
    cookies[:motion] = "reduced"

    post motion_path(locale: :en), params: { reduced: "off" }
    follow_redirect!

    assert_nil cookies[:motion].presence
    assert_select "html[data-motion]", 0
    assert_select "button.motion-switch[aria-pressed=false]", text: "Reduced motion"
  end

  test "an unknown choice removes the cookie" do
    cookies[:motion] = "reduced"

    post motion_path(locale: :en), params: { reduced: "maybe" }

    assert_nil cookies[:motion].presence
  end

  test "a signed-in player is refused, their own setting rules" do
    sign_in(accounts_players(:player))

    post motion_path(locale: :en), params: { reduced: "on" }

    assert_nil cookies[:motion].presence
    assert_nil accounts_players(:player).reload.reduced_motion
  end

  test "the landing's switch is a form posting to the motion route" do
    get home_path(locale: :en)

    assert_select "form[action='#{motion_path(locale: :en)}'][method=post] button.motion-switch"
  end
end
