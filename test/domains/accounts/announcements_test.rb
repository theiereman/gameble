require "test_helper"

class Accounts::AnnouncementsTest < ActiveSupport::TestCase
  setup do
    @administrator = accounts_players(:administrator)
    @player = accounts_players(:player)
  end

  def event_store = Rails.configuration.event_store

  def create(message_fr: "Nouvelle saison ce soir", message_en: "New season tonight", shown: true)
    Accounts::CreateAnnouncement.new.call(staff: @administrator, message_fr:, message_en:, shown:)
  end

  def banner(player: @player, closed_token: nil) = Accounts::AnnouncementBanner.for(player:, closed_token:)

  test "an announcement is saved with both messages squeezed, publishing its creation" do
    announcement = create(message_fr: "  Nouvelle\n saison  ").value!

    assert_equal "Nouvelle saison", announcement.message_fr
    assert_equal "New season tonight", announcement.message(:en)
    assert_predicate announcement, :shown?
    assert_equal 24, announcement.token.length
    event = event_store.read.stream(Accounts::Announcement.stream_name).last
    assert_kind_of Accounts::AnnouncementCreated, event
    assert_equal({ announcement_id: announcement.id, staff_id: @administrator.id, shown: true }, event.data)
  end

  test "a message missing in either language, or over the limit, is refused" do
    [ { message_fr: " " }, { message_en: nil }, { message_en: "x" * 281 } ].each do |messages|
      assert_no_difference -> { Accounts::Announcement.count } do
        assert_equal :invalid_announcement, create(**messages).failure
      end
    end
    assert create(message_en: "x" * 280).success?
  end

  test "showing an announcement takes any other off the banner" do
    first = create.value!
    second = create(shown: false).value!

    assert_predicate first.reload, :shown?
    assert_not second.shown?

    Accounts::ShowAnnouncement.new.call(staff: @administrator, announcement: second).value!

    assert_not first.reload.shown?
    assert_predicate second.reload, :shown?
    assert_equal second, banner

    create.value!
    assert_equal [ false, false, true ], Accounts::Announcement.order(:id).pluck(:shown)
  end

  test "an announcement taken off the banner shows to nobody, and cannot be taken off twice" do
    announcement = create.value!

    Accounts::HideAnnouncement.new.call(staff: @administrator, announcement:).value!

    assert_nil banner
    assert_nil banner(player: nil)
    assert_equal :announcement_not_shown, Accounts::HideAnnouncement.new.call(staff: @administrator, announcement:).failure
  end

  test "editing rewords the announcement and keeps who closed it" do
    announcement = create.value!
    Accounts::DismissAnnouncement.new.call(player: @player, announcement:).value!

    Accounts::EditAnnouncement.new.call(staff: @administrator, announcement:, message_fr: "Corrigé", message_en: "Fixed").value!

    assert_equal %w[Corrigé Fixed], announcement.reload.slice(:message_fr, :message_en).values
    assert_nil banner
    assert_equal :invalid_announcement,
      Accounts::EditAnnouncement.new.call(staff: @administrator, announcement:, message_fr: "", message_en: "Fixed").failure
  end

  test "a player closes the announcement once for good; a new announcement shows again" do
    announcement = create.value!
    assert_equal announcement, banner
    events = event_store.read.count

    2.times { Accounts::DismissAnnouncement.new.call(player: @player, announcement:).value! }

    assert_nil banner
    assert_equal announcement, banner(player: accounts_players(:moderator))
    assert_equal 1, announcement.dismissals.count
    assert_equal events + 1, event_store.read.count
    assert_kind_of Accounts::AnnouncementDismissed, event_store.read.stream("Accounts::Player$#{@player.id}").last

    newer = create.value!
    assert_equal newer, banner
  end

  test "a visitor's browser hides only the announcement it closed" do
    announcement = create.value!

    assert_equal announcement, banner(player: nil)
    assert_nil banner(player: nil, closed_token: announcement.token)
    assert_equal create.value!, banner(player: nil, closed_token: announcement.token)
  end

  test "deleting a player erases the announcements they closed" do
    announcement = create.value!
    Accounts::DismissAnnouncement.new.call(player: @player, announcement:).value!

    Accounts::DeletePlayer.new.call(player: @player).value!

    assert_equal 0, announcement.dismissals.count
  end
end
