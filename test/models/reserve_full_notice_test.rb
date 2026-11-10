require "test_helper"
require_relative "../support/game_packs"
require_relative "../support/singleton_stub"

class ReserveFullNoticeTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper
  include GamePacks
  include SingletonStub

  setup do
    @player = accounts_players(:player)
    @now = Time.utc(2026, 10, 2, 15, 0)
    @phone = Accounts::RegisterPushDevice.new.call(player: @player, platform: "apple", token: "player-phone", locale: "fr").value!
  end

  def open_packs(count) = count.times { Game::OpenPack.new.call(player: @player).value! }
  def notices = enqueued_jobs.select { it[:job] == ReserveFullNoticeJob }
  def pushes = enqueued_jobs.select { it[:job] == ApplicationPushNotificationJob }

  def perform_configured(full_at)
    stub_singleton(PushNotices, :deliverable?, ->(_device) { true }) { ReserveFullNoticeJob.perform_now(@player.id, full_at) }
  end

  test "an opening that leaves the reserve half an hour or more from full schedules one notice for the moment it fills" do
    travel_to(@now) do
      Game::FillBank.new.call(player: @player).value!
      open_packs(2)

      assert_empty notices

      open_packs(1)

      assert_equal 1, notices.size
      assert_equal (@now + 30.minutes).to_f, notices.sole[:at].to_f
      assert_equal @player.id, notices.sole[:args].first
    end
  end

  test "a special capsule leaves the reserve as it was and schedules nothing" do
    travel_to(@now) do
      Game::FillBank.new.call(player: @player).value!
      open_packs(3)
      clear_enqueued_jobs
      create_pack(@player, kind: :bonus)

      Game::OpenPack.new.call(player: @player, reserve: "special").value!

      assert_empty notices
    end
  end

  test "the notice is pushed once the reserve is full, never for a fill that a later opening pushed back" do
    full_at = travel_to(@now) do
      Game::FillBank.new.call(player: @player).value!
      open_packs(3)
      Game::Reserve.full_at(@player.id)
    end

    travel_to(full_at - 1.minute) { perform_configured(full_at) }
    assert_empty pushes

    travel_to(full_at + 1.second) { perform_configured(full_at) }
    assert_equal 1, pushes.size
    _class_name, attributes, device = pushes.sole[:args]
    assert_equal "Réserve pleine", attributes["title"]
    assert_equal @phone.to_global_id.to_s, device["_aj_globalid"]

    clear_enqueued_jobs
    travel_to(full_at - 1.minute) { open_packs(1) }
    travel_to(full_at + 1.second) { perform_configured(full_at) }
    assert_empty pushes
  end

  test "the notification says how many capsules wait and leads to the booster" do
    notification = ReserveFullNotice.notification("en")

    assert_equal "Reserve full", notification.title
    assert_equal "Your 10 capsules are waiting. Open one so the next ones keep coming.", notification.body
    assert_equal({ path: "/en/booster" }, notification.data)
  end
end
