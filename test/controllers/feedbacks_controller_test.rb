require "test_helper"
require_relative "../support/steam_sign_in"

class FeedbacksControllerTest < ActionDispatch::IntegrationTest
  include SteamSignIn

  setup { @player = accounts_players(:player) }

  test "a signed-in player sees the form of a feature open to feedback" do
    sign_in(@player)

    get new_feedback_path(locale: :en, feature: "duels")

    assert_response :success
    assert_select "form[action='/en/feedback'][method=post]" do
      assert_select "input[type=hidden][name=feature][value=duels]"
      assert_select "textarea[name=message][required]"
    end
  end

  test "a feature that is not open is an unknown address" do
    sign_in(@player)

    get new_feedback_path(locale: :en, feature: "market")

    assert_response :not_found
  end

  test "sending a feedback saves it and returns to the feature with a thanks" do
    sign_in(@player)

    assert_difference -> { Accounts::Feedback.count }, 1 do
      post feedback_path(locale: :en), params: { feature: "duels", message: "The clock is too short." }
    end

    assert_redirected_to duels_path(locale: :en)
    assert_equal "Thank you, your feedback is sent.", flash[:notice]
  end

  test "an empty feedback comes back to the form with the reason" do
    sign_in(@player)

    assert_no_difference -> { Accounts::Feedback.count } do
      post feedback_path(locale: :en), params: { feature: "duels", message: " " }
    end

    assert_redirected_to new_feedback_path(locale: :en, feature: "duels")
    assert_equal "Write your feedback in 1000 characters at most.", flash[:alert]
  end

  test "a visitor cannot send one" do
    assert_no_difference -> { Accounts::Feedback.count } do
      post feedback_path(locale: :en), params: { feature: "duels", message: "Hello" }
    end
  end

  test "the duels screen shows the alpha tag and the feedback button" do
    sign_in(@player)

    get duels_path(locale: :en)

    assert_select ".alpha-banner .alpha-tag", "ALPHA"
    assert_select ".alpha-banner", text: /may contain bugs and balance problems/
    assert_select ".alpha-banner a[href=?]", "/en/feedback/new?feature=duels", text: "Send feedback"
  end
end
