require "test_helper"
require_relative "../support/counting_rate_limit"
require_relative "../support/steam_sign_in"

class ReportsControllerTest < ActionDispatch::IntegrationTest
  include CountingRateLimit
  include SteamSignIn

  setup do
    @owner = accounts_players(:player)
    @reporter = Accounts::Player.create!(steam_id: "76561197960390201")
  end

  def report_path_of(owner, locale: :en) = brother_report_path(locale:, token: owner.token)

  test "a signed-in visitor of a profile sees SIGNALER and the dialog with four reasons" do
    sign_in(@reporter)

    get brother_path(locale: :fr, token: @owner.token)

    assert_response :success
    assert_select ".profile-summary button[aria-haspopup=dialog][data-dialog-opener-dialog-value=report-dialog]", "SIGNALER"
    assert_select "dialog#report-dialog form[action=?][method=post]", report_path_of(@owner, locale: :fr)
    assert_equal [ "Pseudo inapproprié", "Triche ou abus", "Harcèlement", "Autre" ],
      css_select("#report-dialog .report-dialog__reason span").map(&:text)
    assert_select "#report-dialog input[type=radio][name=reason][required]", 4
    assert_select "#report-dialog button[type=submit]", "ENVOYER LE SIGNALEMENT"
    assert_select "#report-dialog", text: /Le joueur ne verra pas qui l'a signalé/
  end

  test "the owner of the profile has no SIGNALER" do
    sign_in(@owner)

    get brother_path(locale: :en, token: @owner.token)

    assert_response :success
    assert_select "#report-dialog", false
    assert_select ".profile-summary button", false
  end

  test "a signed-out visitor's SIGNALER opens the sign-in panel and no report dialog is sent" do
    get brother_path(locale: :en, token: @owner.token)

    assert_response :success
    assert_select ".profile-summary button[data-dialog-opener-dialog-value=sign-in-panel]", "REPORT"
    assert_select "#report-dialog", false
  end

  test "a player reports a profile with one reason and is thanked; the reported player learns nothing" do
    sign_in(@reporter)

    assert_difference "Accounts::Report.count", 1 do
      post report_path_of(@owner), params: { reason: "harassment" }
    end

    assert_redirected_to brother_path(locale: :en, token: @owner.token)
    report = Accounts::Report.sole
    assert_equal [ @reporter, @owner, "harassment" ], [ report.reporter, report.reported, report.reason ]
    follow_redirect!
    assert_select ".toast", text: /The moderation team will review this profile\. The player will not see who reported them\./

    # The reported player's own pages carry no trace of the report.
    delete session_path
    sign_in(@owner)
    get brother_path(locale: :en, token: @owner.token)
    assert_no_match(/moderator|#{@reporter.token}|#{@reporter.steam_id}/, response.body)
    assert_no_match(/will review this profile\. The player will not/, response.body.sub(%r{<dialog id="report-dialog".*?</dialog>}m, ""))
  end

  test "a repeat is thanked the same and adds nothing" do
    sign_in(@reporter)
    post report_path_of(@owner), params: { reason: "cheating" }

    assert_no_difference "Accounts::Report.count" do
      post report_path_of(@owner), params: { reason: "other" }
    end
    assert_redirected_to brother_path(locale: :en, token: @owner.token)
    assert_nil flash[:alert]
    assert_predicate flash[:notice], :present?
  end

  test "no or an unknown reason is refused with a message and stores nothing" do
    sign_in(@reporter)

    [ {}, { reason: "spam" } ].each do |params|
      assert_no_difference "Accounts::Report.count" do
        post report_path_of(@owner), params:
      end
      assert_redirected_to brother_path(locale: :en, token: @owner.token)
      assert_equal "Choose a reason to send the report.", flash[:alert]
    end
  end

  test "a visitor is refused and sent to sign in; nothing is stored" do
    assert_no_difference "Accounts::Report.count" do
      post report_path_of(@owner), params: { reason: "cheating" }
    end

    assert_redirected_to home_path(locale: :en)
    assert_equal "Sign in through Steam to do that.", flash[:alert]
  end

  test "reporting oneself is refused" do
    sign_in(@owner)

    assert_no_difference "Accounts::Report.count" do
      post report_path_of(@owner), params: { reason: "cheating" }
    end
    assert_equal "You cannot report your own profile.", flash[:alert]
  end

  test "a hidden profile or an unknown token is the unavailable page, and cannot be reported" do
    sign_in(@reporter)
    @owner.update!(visibility: "private")

    assert_no_difference "Accounts::Report.count" do
      post report_path_of(@owner), params: { reason: "cheating" }
      assert_response :not_found
      post brother_report_path(locale: :en, token: "1" * 24), params: { reason: "cheating" }
      assert_response :not_found
    end
  end

  test "staff report a private, a friends-only and a banned profile they may read" do
    banned = accounts_players(:banned)
    sign_in(accounts_players(:moderator))

    assert_difference "Accounts::Report.count", 2 do
      @owner.update!(visibility: "private")
      post report_path_of(@owner), params: { reason: "cheating" }
      assert_redirected_to brother_path(locale: :en, token: @owner.token)
      assert_predicate flash[:notice], :present?

      post report_path_of(banned), params: { reason: "other" }
      assert_redirected_to brother_path(locale: :en, token: banned.token)
      assert_predicate flash[:notice], :present?
    end
  end

  test "a report sent from a friend's profile comes back to the Friends screen" do
    Game::Friendship.create!(low_player_id: [ @owner.id, @reporter.id ].min, high_player_id: [ @owner.id, @reporter.id ].max)
    @owner.update!(visibility: "friends_only")
    sign_in(@reporter)

    assert_difference "Accounts::Report.count", 1 do
      post report_path_of(@owner), params: { reason: "harassment", from: "friends" }
    end
    assert_redirected_to friends_path(locale: :en)
    assert_predicate flash[:notice], :present?

    post report_path_of(@owner), params: { from: "friends" }
    assert_redirected_to friends_path(locale: :en)
    assert_equal "Choose a reason to send the report.", flash[:alert]
  end

  test "a player is limited per minute" do
    sign_in(@reporter)

    with_counting_rate_limit(ReportsController) do
      10.times { post report_path_of(@owner), params: { reason: "cheating" } }
      assert_redirected_to brother_path(locale: :en, token: @owner.token)

      post report_path_of(@owner), params: { reason: "cheating" }
      assert_redirected_to home_path(locale: :en)
      assert_equal "Too many attempts in a minute. Try again in a moment.", flash[:alert]
    end
  end
end
