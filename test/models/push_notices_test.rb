require "test_helper"
require_relative "../support/singleton_stub"

class PushNoticesTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper
  include SingletonStub

  setup do
    @alice = accounts_players(:player)
    @bob = accounts_players(:moderator)
    @one = catalog_card_seasons(:portal_one).id
    @three = catalog_card_seasons(:rare_card_one).id
    low, high = [ @alice.id, @bob.id ].minmax
    Game::Friendship.create!(low_player_id: low, high_player_id: high)
    Game::Holding.create!(player_id: @alice.id, card_season_id: @one, quantity: 3, reserved: 0)
    Game::Holding.create!(player_id: @bob.id, card_season_id: @three, quantity: 2, reserved: 0)
  end

  def propose
    Game::ProposeTrade.new.call(player: @alice, recipient: @bob, offer: { @one => 1 }, request: { @three => 1 })
  end

  test "a trade offer is pushed to its recipient once the proposal commits" do
    assert_enqueued_with(job: PushNoticeJob, args: [ [ { player_id: @bob.id, actor_id: @alice.id, kind: "trade_proposed" } ] ]) do
      assert propose.success?
    end
  end

  test "a counter-offer goes to the other party, an acceptance to the proposer, an invitation to its recipient" do
    trade = { trade_id: 1, proposer_id: @alice.id, recipient_id: @bob.id }

    assert_equal [ { player_id: @bob.id, actor_id: @alice.id, kind: "trade_countered" } ], PushNotices.notices(Game::TradeCountered.new(data: trade))
    assert_equal [ { player_id: @alice.id, actor_id: @bob.id, kind: "trade_accepted" } ], PushNotices.notices(Game::TradeAccepted.new(data: trade))
    assert_equal [ { player_id: @bob.id, actor_id: @alice.id, kind: "invitation_sent" } ],
      PushNotices.notices(Game::InvitationSent.new(data: { invitation_id: 1, sender_id: @alice.id, recipient_id: @bob.id }))
    assert_empty PushNotices.notices(Game::TradeDeclined.new(data: trade))
  end

  test "the notification is written in the device's locale and leads to the screen it is about" do
    notification = PushNotices.notification("trade_proposed", actor_name: "Alice", locale: "fr")

    assert_equal "Nouvelle offre d'échange", notification.title
    assert_equal "Alice vous propose un échange.", notification.body
    assert_equal({ path: "/fr/trades" }, notification.data)
    assert_equal "/en/friends", PushNotices.notification("invitation_sent", actor_name: "Alice", locale: "en").data[:path]
  end

  test "a platform without its keys gets nothing" do
    device = Accounts::PushDevice.new(platform: "apple")

    stub_singleton(ActionPushNative, :config, -> { { apple: { key_id: "K", encryption_key: "E", team_id: "T" } } }) { assert PushNotices.deliverable?(device) }
    stub_singleton(ActionPushNative, :config, -> { { apple: { key_id: "", encryption_key: "E", team_id: "T" } } }) { assert_not PushNotices.deliverable?(device) }
    stub_singleton(ActionPushNative, :config, -> { {} }) { assert_not PushNotices.deliverable?(device) }
  end
end
