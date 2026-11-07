require "test_helper"
require_relative "../../support/game_packs"

class Game::ChooseAvatarTest < ActiveSupport::TestCase
  include GamePacks

  setup do
    @player = accounts_players(:player)
    @other = accounts_players(:moderator)
    Game::AchievementUnlock.record(@player.id, "first_booster", Time.current)
  end

  def choose(avatar, player: @player) = Game::ChooseAvatar.new.call(player:, avatar:)

  def stored = Game::PlayerState.where(player_id: @player.id).pick(:active_avatar)

  def events = game_events(@player, Game::AvatarChosen)

  test "an avatar whose achievement is earned is stored, shown and published once" do
    result = choose("novice")

    assert result.success?
    assert_equal "novice", stored
    assert_equal "novice", Game::ActiveAvatar.call(@player).key
    assert_equal [ { player_id: @player.id, avatar: "novice" } ], events.map(&:data)
  end

  test "an unclaimed achievement unlocks its avatar too" do
    Game::AchievementUnlock.record(@player.id, "first_epic", Time.current, claimed: false)

    assert choose("oracle").success?
  end

  test "the default avatar needs no achievement and clears the choice" do
    choose("novice")

    assert choose("default").success?
    assert_nil stored
    assert Game::ActiveAvatar.call(@player).default?
  end

  test "an avatar whose achievement is not earned is refused and writes nothing" do
    assert_no_difference -> { Rails.configuration.event_store.read.count } do
      assert_equal :avatar_locked, choose("oracle").failure
      assert_equal :unknown_avatar, choose("dragon").failure
    end

    assert_nil stored
  end

  test "a player who never chose shows the default avatar, and the batch maps every player" do
    choose("novice")

    avatars = Game::ActiveAvatar.for_players([ @player, @other ])

    assert_equal({ @player.id => "novice", @other.id => "default" }, avatars.transform_values(&:key))
  end

  test "the free avatars need no achievement" do
    other = choose("botanist", player: @other)

    assert other.success?
    assert_equal "botanist", Game::ActiveAvatar.call(@other).key
  end

  test "the shelf lists every avatar, the free ones open and the others locked until their achievement is earned" do
    choose("novice")

    rows = Game::AvatarShelf.call(@player)

    assert_equal %w[default mechanic pilot cartographer botanist streamer elder astronaut punk chef robot cat alien slime owl novice archivist guardian oracle], rows.map(&:key)
    assert_equal %w[default mechanic pilot cartographer botanist streamer elder astronaut punk chef robot cat alien slime owl novice], rows.reject(&:locked?).map(&:key)
    assert_equal %w[novice], rows.select(&:active).map(&:key)
  end

  test "only an administrator can wear the grand master avatar, and nobody else sees it" do
    administrator = accounts_players(:administrator)
    Game::AchievementUnlock.record(@player.id, "boosters_500", Time.current)

    assert choose("grand_master", player: administrator).success?
    assert_equal "grand_master", Game::ActiveAvatar.call(administrator).key
    assert_equal :avatar_locked, choose("oracle", player: administrator).failure
    assert_equal :unknown_avatar, choose("grand_master").failure
    assert_equal :unknown_avatar, choose("grand_master", player: @other).failure
    assert_not_includes Game::AvatarShelf.call(@player).map(&:key), "grand_master"
    assert_includes Game::AvatarShelf.call(administrator).reject(&:locked?).map(&:key), "grand_master"
  end

  test "a grand master avatar stored for a player who is no longer an administrator shows the default" do
    administrator = accounts_players(:administrator)
    choose("grand_master", player: administrator)
    administrator.update!(role: :player)

    assert Game::ActiveAvatar.call(administrator).default?
  end
end
