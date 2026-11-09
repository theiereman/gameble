require "test_helper"
require_relative "../../support/hidden_back_office"
require_relative "../../support/steam_sign_in"

module BackOffice
  # The announcements of the back-office, administrators only: written in
  # both languages, shown on the banner one at a time.
  class AnnouncementsControllerTest < ActionDispatch::IntegrationTest
    include HiddenBackOffice
    include SteamSignIn

    setup do
      @administrator = accounts_players(:administrator)
    end

    def create_announcement(shown: true, message_en: "New season tonight")
      Accounts::CreateAnnouncement.new.call(staff: @administrator, message_fr: "Nouvelle saison ce soir", message_en:, shown:).value!
    end

    test "an administrator sees every announcement, newest first, and the form for a new one" do
      older = create_announcement(message_en: "Older")
      newer = create_announcement(shown: false, message_en: "Newer")
      Accounts::DismissAnnouncement.new.call(player: accounts_players(:player), announcement: older)
      sign_in(@administrator)

      get back_office_announcements_path(locale: :en)

      assert_response :success
      assert_select "h1", "The announcements"
      assert_select "#announcement-banner", 0
      assert_select "form[action='/en/back-office/announcements'][method=post] textarea[name=message_fr][required]"
      assert_equal [ newer.token, older.token ], css_select("[data-announcement-token]").map { it["data-announcement-token"] }
      assert_select "[data-announcement-token='#{older.token}'][data-announcement-state=shown]" do
        assert_select "[data-announcement-dismissals]", "closed by one player"
        assert_select "form[action='/en/back-office/announcements/#{older.token}/withdraw'] button", "Take off the banner"
        assert_select "textarea[name=message_en]", "Older"
      end
      assert_select "[data-announcement-token='#{newer.token}'][data-announcement-state=hidden]" do
        assert_select "form[action='/en/back-office/announcements/#{newer.token}/publish'] button", "Show on the banner"
      end
      assert_select "[style]", false
    end

    test "the dashboard leads an administrator to the announcements" do
      sign_in(@administrator)

      get back_office_path(locale: :fr)

      assert_select "a[href='/fr/back-office/announcements'] .office-tile__title", "Les annonces"
    end

    test "an administrator creates an announcement that goes straight to the banner" do
      sign_in(@administrator)

      post back_office_announcements_path(locale: :fr), params: { message_fr: "Maintenance à 22h", message_en: "Maintenance at 10pm", shown: "1" }

      assert_redirected_to back_office_announcements_path(locale: :fr)
      assert_equal "L'annonce est enregistrée.", flash[:notice]
      assert_predicate Accounts::Announcement.sole, :shown?
    end

    test "a message missing a language is refused with the reason" do
      sign_in(@administrator)

      assert_no_difference -> { Accounts::Announcement.count } do
        post back_office_announcements_path(locale: :en), params: { message_fr: "Bonjour", message_en: "", shown: "0" }
      end
      assert_equal "Write the announcement in both languages, 280 characters at most each.", flash[:alert]
    end

    test "an administrator rewords, takes off and shows again an announcement" do
      announcement = create_announcement
      sign_in(@administrator)

      patch back_office_announcement_path(locale: :en, token: announcement.token), params: { message_fr: "Corrigé", message_en: "Fixed" }
      assert_equal "Fixed", announcement.reload.message_en

      post withdraw_back_office_announcement_path(locale: :en, token: announcement.token)
      assert_not announcement.reload.shown?
      assert_equal "The announcement left the banner.", flash[:notice]

      post publish_back_office_announcement_path(locale: :en, token: announcement.token)
      assert_predicate announcement.reload, :shown?
    end

    test "a moderator is refused the announcements" do
      announcement = create_announcement
      sign_in(accounts_players(:moderator))

      get back_office_announcements_path(locale: :en)
      assert_response :forbidden
      post withdraw_back_office_announcement_path(locale: :en, token: announcement.token)

      assert_predicate announcement.reload, :shown?
    end
  end
end
