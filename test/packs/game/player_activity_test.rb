require "test_helper"

class Game::PlayerActivityTest < ActiveSupport::TestCase
  setup do
    @alice = accounts_players(:player)
    @bob = accounts_players(:moderator)
    @now = Time.utc(2026, 10, 7, 15, 0)
  end

  def activity(player) = Game::PlayerState.find_by!(player_id: player.id).slice(:last_activity, :last_activity_at).values

  def befriend(first, second)
    low, high = [ first.id, second.id ].minmax
    Game::Friendship.create!(low_player_id: low, high_player_id: high)
  end

  test "opening a pack and collecting the daily booster are the opener's activity" do
    travel_to(@now) do
      Game::FillBank.new.call(player: @alice).value!
      Game::OpenPack.new.call(player: @alice).value!
      assert_equal [ "opening_pack", @now ], activity(@alice)
    end

    travel_to(@now + 1.minute) do
      Game::CollectDailyBonus.new.call(player: @alice).value!
      assert_equal [ "collecting_daily", @now + 1.minute ], activity(@alice)
    end
    assert_equal [ nil, nil ], activity(@bob)
  end

  test "sending an invitation is the sender's activity, accepting it the recipient's" do
    travel_to(@now) do
      invitation = Game::SendInvitation.new.call(player: @alice, code: "8F2D-K9XM").value!
      assert_equal [ "making_friends", @now ], activity(@alice)
      assert_equal [ nil, nil ], activity(@bob)

      Game::AcceptInvitation.new.call(player: @bob, token: invitation.token).value!
      assert_equal [ "making_friends", @now ], activity(@bob)
    end
  end

  test "countering is the counterer's activity, accepting the recipient's" do
    befriend(@alice, @bob)
    one = catalog_card_seasons(:portal_one).id
    rare = catalog_card_seasons(:rare_card_one).id
    Game::Holding.create!(player_id: @alice.id, card_season_id: one, quantity: 2, reserved: 0)
    Game::Holding.create!(player_id: @bob.id, card_season_id: rare, quantity: 2, reserved: 0)
    trade = travel_to(@now) { Game::ProposeTrade.new.call(player: @alice, recipient: @bob, offer: { one => 1 }, request: { rare => 1 }).value! }

    travel_to(@now + 1.minute) do
      Game::CounterTrade.new.call(player: @bob, trade_id: trade.id, revision: Game::Trade.find(trade.id).revision, offer: { rare => 1 }, request: { one => 2 }).value!
      assert_equal [ "trading", @now + 1.minute ], activity(@bob)
    end

    travel_to(@now + 2.minutes) do
      Game::AcceptTrade.new.call(player: @alice, trade_id: trade.id, revision: Game::Trade.find(trade.id).revision).value!
      assert_equal [ "trading", @now + 2.minutes ], activity(@alice)
    end
  end

  test "proposing and cancelling are the proposer's activity, declining the recipient's" do
    befriend(@alice, @bob)
    one = catalog_card_seasons(:portal_one).id
    Game::Holding.create!(player_id: @alice.id, card_season_id: one, quantity: 2, reserved: 0)
    Game::Holding.create!(player_id: @bob.id, card_season_id: catalog_card_seasons(:rare_card_one).id, quantity: 1, reserved: 0)
    request = { catalog_card_seasons(:rare_card_one).id => 1 }

    travel_to(@now) do
      trade = Game::ProposeTrade.new.call(player: @alice, recipient: @bob, offer: { one => 1 }, request:).value!
      assert_equal [ "trading", @now ], activity(@alice)

      Game::DeclineTrade.new.call(player: @bob, trade_id: trade.id, revision: Game::Trade.find(trade.id).revision).value!
      assert_equal [ "trading", @now ], activity(@bob)
    end

    travel_to(@now + 5.minutes) do
      trade = Game::ProposeTrade.new.call(player: @alice, recipient: @bob, offer: { one => 1 }, request:).value!
      Game::CancelTrade.new.call(player: @alice, trade_id: trade.id).value!
      assert_equal [ "trading", @now + 5.minutes ], activity(@alice)
    end
  end

  test "a player without a state row gets one; the operation never fails for it" do
    Game::PlayerState.where(player_id: @alice.id).delete_all

    travel_to(@now) do
      assert Game::SendInvitation.new.call(player: @alice, code: "8F2D-K9XM").success?
    end

    assert_equal [ "making_friends", @now ], activity(@alice)
  end

  test "the activity is the only thing written: the watermark is kept and nothing more is published" do
    seen = @now - 1.day
    Game::PlayerState.where(player_id: @alice.id).update_all(collection_seen_up_to: seen)

    travel_to(@now) do
      assert_difference -> { Rails.configuration.event_store.read.count }, 1 do
        Game::SendInvitation.new.call(player: @alice, code: "8F2D-K9XM").value!
      end
    end

    assert_equal seen, Game::PlayerState.find_by!(player_id: @alice.id).collection_seen_up_to
  end

  test "the handler is subscribed to each event it words" do
    Game::Handlers::PlayerActivity::EVENTS.each_key do |event|
      assert_includes Rails.configuration.event_store.subscribers_for(event), Game::Handlers::PlayerActivity, event.name
    end
  end
end
