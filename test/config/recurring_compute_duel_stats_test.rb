require "test_helper"
require "fugit"

class RecurringComputeDuelStatsTest < ActiveSupport::TestCase
  test "every duel profile is recomputed each Monday at midnight UTC in development and production" do
    recurring = YAML.safe_load(Rails.root.join("config/recurring.yml").read, aliases: true)

    %w[development production].each do |env|
      task = recurring.dig(env, "compute_duel_stats")
      assert_equal({ "class" => "Game::ComputeDuelStatsJob", "queue" => "default", "args" => [ "weekly" ] }, task.except("schedule"), env)
      assert_equal "0 0 * * 1 UTC", Fugit.parse(task.fetch("schedule")).to_cron_s, env
    end
  end
end
