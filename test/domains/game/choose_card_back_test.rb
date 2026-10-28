require "test_helper"
require_relative "../../support/game_packs"

class Game::ChooseCardBackTest < ActiveSupport::TestCase
  include GamePacks

  setup do
    @player = accounts_players(:player)
    Game::CardBackUnlock.record(@player.id, "set-theme-rpg", Time.current)
  end

  def choose(back, player: @player) = Game::ChooseCardBack.new.call(player:, back:)

  def stored = Game::PlayerState.where(player_id: @player.id).pick(:active_card_back)

  def events = game_events(@player, Game::CardBackChosen)

  test "an unlocked back is stored, becomes the active one and is published once" do
    result = choose("set-theme-rpg")

    assert result.success?
    assert_equal "set-theme-rpg", stored
    assert_equal "set-theme-rpg", Game::CardBacks.active_key(@player)
    assert_equal [ { player_id: @player.id, back: "set-theme-rpg", season: nil } ], events.map(&:data)
  end

  test "Standard needs no unlock and brings the player back to it" do
    choose("set-theme-rpg")

    assert choose("standard").success?
    assert_equal "standard", Game::CardBacks.active_key(@player)
    assert_equal 2, events.size
  end

  test "a back in the catalogue that is not unlocked is refused and writes nothing" do
    assert_no_difference -> { Rails.configuration.event_store.read.count } do
      assert_equal :back_locked, choose("set-theme-horror").failure
    end

    assert_nil stored
  end

  test "an unlock of another player does not unlock the back" do
    Game::CardBackUnlock.record(accounts_players(:moderator).id, "set-theme-horror", Time.current)

    assert_equal :back_locked, choose("set-theme-horror").failure
  end

  test "a key outside the catalogue is refused and writes nothing" do
    assert_no_difference -> { Rails.configuration.event_store.read.count } do
      assert_equal :unknown_back, choose("not-a-back").failure
      assert_equal :unknown_back, choose("").failure
    end

    assert_nil stored
  end

  test "a banned player cannot choose a back" do
    @player.update!(banned_at: Time.current)

    assert_equal :player_required, choose("set-theme-rpg").failure
  end

  test "both refusals have a message in each locale" do
    %i[en fr].each do |locale|
      I18n.with_locale(locale) do
        %i[back_locked unknown_back].each { assert_not_includes Game::ChooseCardBack.failure_message(it), "translation missing" }
      end
    end
  end
end
