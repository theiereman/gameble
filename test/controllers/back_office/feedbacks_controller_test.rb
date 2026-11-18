require "test_helper"
require_relative "../../support/hidden_back_office"
require_relative "../../support/steam_sign_in"

module BackOffice
  # What players wrote about the features under test, by feature, administrators only.
  class FeedbacksControllerTest < ActionDispatch::IntegrationTest
    include HiddenBackOffice
    include SteamSignIn

    test "an administrator reads the feedback of each feature, newest first" do
      older = Accounts::SendFeedback.new.call(player: accounts_players(:player), feature: "duels", message: "First thought").value!
      newer = Accounts::SendFeedback.new.call(player: accounts_players(:moderator), feature: "duels", message: "Second thought").value!
      sign_in(accounts_players(:administrator))

      get back_office_feedbacks_path(locale: :en)

      assert_response :success
      assert_select "h1", "Testing"
      assert_select "[data-feedback-feature=duels] h2", text: /Duels · 2 feedbacks/
      assert_equal [ newer.token, older.token ], css_select("[data-feedback-token]").map { it["data-feedback-token"] }
      assert_select "[data-feedback-token='#{older.token}']", text: /First thought/
    end

    test "a feature without feedback says so" do
      sign_in(accounts_players(:administrator))

      get back_office_feedbacks_path(locale: :en)

      assert_select "[data-feedback-feature=duels]", text: /Nothing yet/
    end

    test "the back-office home links to it for an administrator only" do
      sign_in(accounts_players(:administrator))
      get back_office_path(locale: :en)
      assert_select "a[data-office-tile=feedbacks]"

      delete session_path(locale: :en)
      sign_in(accounts_players(:moderator))
      get back_office_path(locale: :en)
      assert_select "a[data-office-tile=feedbacks]", 0

      get back_office_feedbacks_path(locale: :en)
      assert_response :forbidden
    end

    test "a player does not find it" do
      sign_in(accounts_players(:player))

      get back_office_feedbacks_path(locale: :en)

      assert_unknown_address
    end
  end
end
