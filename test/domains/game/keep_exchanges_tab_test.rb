require "test_helper"
require_relative "../../support/game_packs"

# Game::KeepExchangesTab: the trades sub-tab a player last used, kept so the trades tab leads back to it.
class Game::KeepExchangesTabTest < ActiveSupport::TestCase
  include GamePacks

  setup do
    @player = accounts_players(:player)
  end

  def keep(tab, player: @player) = Game::KeepExchangesTab.new.call(player:, tab:)

  def kept = Game::PlayerState.where(player_id: @player.id).pick(:exchanges_tab)

  def events = game_events(@player, Game::ExchangesTabKept)

  test "on the market until the player keeps another sub-tab" do
    assert_nil kept
    assert_equal "market", Game::ExchangesTab.call(@player)
    assert_equal "market", Game::ExchangesTab.call(nil)
  end

  test "a new sub-tab is stored and published once, with ids only" do
    result = keep("friends")

    assert result.success?
    assert_equal "friends", result.value!
    assert_equal "friends", kept
    assert_equal "friends", Game::ExchangesTab.call(@player)
    assert_equal [ { player_id: @player.id } ], events.map(&:data)

    assert keep("market").success?
    assert_equal "market", Game::ExchangesTab.call(@player)
    assert_equal 2, events.size
  end

  test "the sub-tab already kept writes nothing and publishes nothing" do
    keep("friends")

    assert_no_changes -> { Game::PlayerState.find_by!(player_id: @player.id).updated_at } do
      assert_no_difference -> { Rails.configuration.event_store.read.count } do
        assert_equal "friends", keep("friends").value!
      end
    end
  end

  test "the market is already kept the first time: nothing written" do
    assert_no_difference -> { Rails.configuration.event_store.read.count } do
      assert keep("market").success?
    end
    assert_nil kept
  end

  test "a player without a state row gets one with the season markers" do
    Game::PlayerState.where(player_id: @player.id).delete_all

    assert keep("friends").success?

    state = Game::PlayerState.find_by!(player_id: @player.id)
    assert_equal "friends", state.exchanges_tab
    assert_equal Game::PlayerState.markers_at_published_season.stringify_keys,
      state.attributes.slice("allocation_received_season", "allocation_seen_season")
  end

  [ "foo", "", nil, 1, [ "friends" ] ].each do |tab|
    test "an unknown tab #{tab.inspect} is refused and writes nothing" do
      assert_no_difference -> { Rails.configuration.event_store.read.count } do
        assert_equal :unknown_tab, keep(tab).failure
      end
      assert_nil kept
    end
  end

  test "a visitor is refused" do
    assert_equal :player_required, keep("friends", player: nil).failure
  end

  test "the database refuses any other value" do
    assert_raises(ActiveRecord::StatementInvalid) do
      Game::PlayerState.where(player_id: @player.id).update_all(exchanges_tab: "duels")
    end
  end
end
