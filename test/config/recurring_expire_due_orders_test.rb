require "test_helper"

class RecurringExpireDueOrdersTest < ActiveSupport::TestCase
  test "due buy orders expire every minute in development and production" do
    recurring = YAML.safe_load(Rails.root.join("config/recurring.yml").read, aliases: true)

    %w[development production].each do |env|
      assert_equal({ "class" => "Game::Market::ExpireDueOrdersJob", "queue" => "default", "schedule" => "every minute" }, recurring.dig(env, "expire_due_orders"), env)
    end
  end
end
