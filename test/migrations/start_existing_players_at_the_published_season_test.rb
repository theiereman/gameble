require "test_helper"
require Rails.root.join("db/migrate/20261028110001_start_existing_players_at_the_published_season")

class StartExistingPlayersAtThePublishedSeasonTest < ActiveSupport::TestCase
  setup do
    @players = %i[player moderator administrator].map { accounts_players(it).id }
    Catalog::Season.create!(status: :published, number: 3, published_at: Time.current)
  end

  def markers = Game::PlayerState.where(player_id: @players).order(:player_id).pluck(:player_id, :allocation_received_season, :allocation_seen_season).to_h { [ it[0], it[1..] ] }

  def migrate = ActiveRecord::Migration.suppress_messages { StartExistingPlayersAtThePublishedSeason.new.up }

  test "players with neither marker start at the highest published season" do
    Game::PlayerState.where(player_id: @players).update_all(allocation_received_season: nil, allocation_seen_season: nil)

    migrate

    assert_equal [ [ 3, 3 ] ], markers.values.uniq
  end

  test "players already marked keep their markers" do
    first, second, third = @players.sort
    Game::PlayerState.where(player_id: first).update_all(allocation_received_season: nil, allocation_seen_season: nil)
    Game::PlayerState.where(player_id: second).update_all(allocation_received_season: 1, allocation_seen_season: 1)
    Game::PlayerState.where(player_id: third).update_all(allocation_received_season: 2, allocation_seen_season: nil)

    migrate

    assert_equal({ first => [ 3, 3 ], second => [ 1, 1 ], third => [ 2, nil ] }, markers)
  end

  def without_published_season = Class.new(StartExistingPlayersAtThePublishedSeason) { def select_value(*) = nil }

  test "nothing changes while no season is published" do
    Game::PlayerState.where(player_id: @players).update_all(allocation_received_season: nil, allocation_seen_season: nil)

    ActiveRecord::Migration.suppress_messages { without_published_season.new.up }

    assert_equal [ [ nil, nil ] ], markers.values.uniq
  end
end
