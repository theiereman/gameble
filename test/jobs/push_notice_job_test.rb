require "test_helper"
require_relative "../support/singleton_stub"

class PushNoticeJobTest < ActiveJob::TestCase
  include SingletonStub

  setup do
    @alice = accounts_players(:player)
    @alice.update!(persona_name: "Alice")
    @bob = accounts_players(:moderator)
    @bob_phone = Accounts::RegisterPushDevice.new.call(player: @bob, platform: "apple", token: "bob-phone", locale: "en").value!
  end

  def notice = { player_id: @bob.id, actor_id: @alice.id, kind: "trade_proposed" }

  def pushes = enqueued_jobs.select { it[:job] == ApplicationPushNotificationJob }

  def perform_configured(notices)
    stub_singleton(PushNotices, :deliverable?, ->(_device) { true }) { PushNoticeJob.perform_now(notices) }
  end

  test "it sends the notice to every device of the player, naming who acted" do
    perform_configured([ notice ])

    assert_equal 1, pushes.size
    _class_name, attributes, device = pushes.sole[:args]
    assert_equal "Alice sent you a trade offer.", attributes["body"]
    assert_equal @bob_phone.to_global_id.to_s, device["_aj_globalid"]
  end

  test "a player without a device, a removed actor or an unconfigured platform send nothing" do
    perform_configured([ notice.merge(player_id: @alice.id) ])
    @alice.update!(banned_at: Time.current)
    perform_configured([ notice ])
    PushNoticeJob.perform_now([ notice.merge(actor_id: accounts_players(:administrator).id) ])

    assert_empty pushes
  end
end
