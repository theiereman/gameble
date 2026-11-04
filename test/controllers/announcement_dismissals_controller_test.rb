require "test_helper"
require_relative "../support/steam_sign_in"

# The red banner of the shown announcement, under the top bar of every screen
# but the back-office's, and its close button.
class AnnouncementDismissalsControllerTest < ActionDispatch::IntegrationTest
  include SteamSignIn

  setup do
    @player = accounts_players(:player)
    @announcement = announce("New season tonight")
  end

  def announce(message_en)
    Accounts::CreateAnnouncement.new.call(staff: accounts_players(:administrator), message_fr: "Nouvelle saison ce soir", message_en:, shown: true).value!
  end

  def dismissal_path(announcement = @announcement) = announcement_dismissal_path(locale: :en, token: announcement.token)

  test "a signed-in player sees the banner in their language under the top bar" do
    sign_in(@player, origin: "/fr")

    get home_path(locale: :fr)

    assert_select "body > header.top-bar + aside#announcement-banner.announcement[aria-label=Annonce][data-turbo-temporary]" do
      assert_select ".announcement__message", "Nouvelle saison ce soir"
      assert_select "form[action='/fr/announcements/#{@announcement.token}/dismissal'] button.announcement__close[aria-label='Fermer l\\'annonce']"
    end
    assert_select "#announcement-banner [style]", 0
  end

  test "a player closes the banner for good, on every screen, with a stream that removes it" do
    sign_in(@player)

    post dismissal_path, as: :turbo_stream

    assert_response :success
    assert_equal %(<turbo-stream action="remove" target="announcement-banner"></turbo-stream>), response.body.strip
    assert_equal [ @player.id ], @announcement.dismissals.pluck(:player_id)
    get home_path(locale: :en)
    assert_select "#announcement-banner", 0

    announce("Maintenance at 10pm")
    get home_path(locale: :en)
    assert_select "#announcement-banner .announcement__message", "Maintenance at 10pm"
  end

  test "a visitor closes the banner in a cookie, writing nothing" do
    get home_path(locale: :en)
    assert_select "#announcement-banner .announcement__message", "New season tonight"

    assert_no_difference -> { Accounts::AnnouncementDismissal.count } do
      post dismissal_path
    end

    assert_redirected_to home_path(locale: :en)
    assert_equal @announcement.token, cookies[ApplicationController::CLOSED_ANNOUNCEMENT_COOKIE.to_s]
    get home_path(locale: :en)
    assert_select "#announcement-banner", 0
  end

  test "the back-office shows no banner" do
    sign_in(accounts_players(:administrator))

    get back_office_path(locale: :en)

    assert_select "#announcement-banner", 0
  end

  test "an announcement taken off the banner shows to nobody" do
    Accounts::HideAnnouncement.new.call(staff: accounts_players(:administrator), announcement: @announcement).value!

    get home_path(locale: :en)

    assert_select "#announcement-banner", 0
  end

  test "an unknown announcement answers not found" do
    post announcement_dismissal_path(locale: :en, token: "A" * 24)

    assert_response :not_found
  end
end
