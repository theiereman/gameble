require "test_helper"

class Game::GrantSupporterTest < ActiveSupport::TestCase
  setup do
    @administrator = accounts_players(:administrator)
    @player = accounts_players(:player)
  end

  def grant(staff: @administrator, player: @player) = Game::GrantSupporter.new.call(staff:, player:)
  def marked_at = Game::PlayerState.find_by(player_id: @player.id)&.supporter_at
  def events = Rails.configuration.event_store.read.of_type(Game::SupporterGranted).count

  test "an administrator marks a player in good standing once and publishes the event" do
    assert_not Game::SupporterStatus.call(@player)

    assert_difference -> { events }, 1 do
      grant.value!
    end

    assert_not_nil marked_at
    assert Game::SupporterStatus.call(@player)
  end

  test "a repeat is refused, the marker stays and no second event is published" do
    grant.value!
    first = marked_at

    assert_no_difference -> { events } do
      assert_equal :supporter_already_granted, grant.failure
    end
    assert_equal first, marked_at
  end

  test "a moderator or a player is refused and nothing is written" do
    [ accounts_players(:moderator), @player ].each do |staff|
      assert_equal :administrator_required, grant(staff:).failure
    end
    assert_nil marked_at
  end

  test "a banned, deleted or unknown player is refused and nothing is written" do
    banned = accounts_players(:banned)
    deleted = Accounts::Player.create!(steam_id: "76561197960999999")
    deleted.update_columns(deleted_at: Time.current, steam_id: nil)

    [ banned, deleted, nil ].each { assert_equal :player_not_found, grant(player: it).failure }
    assert_equal 0, Game::PlayerState.where(player_id: [ banned.id, deleted.id ]).where.not(supporter_at: nil).count
  end
end
