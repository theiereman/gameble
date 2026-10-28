require "test_helper"
require_relative "../../support/catalog_seeds"
require_relative "../../support/game_packs"
require_relative "../../support/game_sets"

class Game::ChooseProfileTitleTest < ActiveSupport::TestCase
  include CatalogSeeds
  include GamePacks
  include GameSets

  setup do
    @player = accounts_players(:player)
    @season, @cards = published_cards(5)
    @valve = insert_set(@cards, { novice: 1, adept: 3, complete: 5 }, kind: "studio", key: "valve", params: { "studio" => "Valve" }, season: @season)
    Game::SetTier.insert_all!(%w[novice adept].map { |tier| { player_id: @player.id, set_id: @valve, tier:, reached_by: "trade", reached_at: Time.current } })
  end

  def choose(player: @player, **title) = Game::ChooseProfileTitle.new.call(player:, **title)

  def stored = Game::PlayerState.where(player_id: @player.id).pick(:active_title_kind, :active_title_key, :active_title_rank)

  def events = game_events(@player, Game::ProfileTitleChosen)

  test "an earned title is stored with its rank and published once" do
    result = choose(rank: "adept", kind: "studio", key: "valve")

    assert result.success?
    assert_equal %w[studio valve adept], stored
    assert_equal [ { player_id: @player.id, kind: "studio", key: "valve", rank: "adept" } ], events.map(&:data)
  end

  test "choosing another title replaces the first" do
    choose(rank: "adept", kind: "studio", key: "valve")
    choose(rank: "novice", kind: "studio", key: "valve")

    assert_equal %w[studio valve novice], stored
    assert_equal 2, events.size
  end

  test "choosing no title clears the stored one" do
    choose(rank: "adept", kind: "studio", key: "valve")

    assert choose.success?
    assert_equal [ nil, nil, nil ], stored
    assert_equal [ nil ], events.last.data.values_at(:rank)
  end

  test "a title the player has not earned is refused and writes nothing" do
    assert_no_difference -> { Rails.configuration.event_store.read.count } do
      assert_equal :title_not_earned, choose(rank: "complete", kind: "studio", key: "valve").failure
      assert_equal :title_not_earned, choose(rank: "adept", kind: "studio", key: "unknown").failure
      assert_equal :title_not_earned, choose(rank: "adept").failure
    end

    assert_nil stored.compact.presence
  end

  test "a banned player cannot choose a title" do
    @player.update!(banned_at: Time.current)

    assert_equal :player_required, choose(rank: "adept", kind: "studio", key: "valve").failure
  end

  test "the active title is the earned one the player chose, and nil once none is chosen" do
    assert_nil Game::ActiveProfileTitle.call(@player)

    choose(rank: "adept", kind: "studio", key: "valve")

    assert_equal "adept", Game::ActiveProfileTitle.call(@player).rank

    choose

    assert_nil Game::ActiveProfileTitle.call(@player)
  end
end
