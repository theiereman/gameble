require "test_helper"

class RecurringDropPresenceTest < ActiveSupport::TestCase
  test "a removed player's market presence is dropped every minute in development and production" do
    recurring = YAML.safe_load(Rails.root.join("config/recurring.yml").read, aliases: true)

    %w[development production].each do |env|
      assert_equal({ "class" => "Game::Market::DropPresenceJob", "queue" => "default", "schedule" => "every minute" }, recurring.dig(env, "drop_presence"), env)
    end
  end
end
