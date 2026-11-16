require "test_helper"

class RecurringSweepDuelDeadlinesTest < ActiveSupport::TestCase
  test "the duel deadlines are swept every 10 seconds in development and production, on the duels queue" do
    recurring = YAML.safe_load(Rails.root.join("config/recurring.yml").read, aliases: true)

    %w[development production].each do |env|
      task = recurring.dig(env, "sweep_duel_deadlines")
      assert_equal({ "class" => "Game::SweepDuelDeadlinesJob", "queue" => "duels", "schedule" => "every 10 seconds" }, task, env)
    end
  end
end
