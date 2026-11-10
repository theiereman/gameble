require "test_helper"

class RecurringReconcileWalletsTest < ActiveSupport::TestCase
  test "the wallets are reconciled every night in development and production" do
    recurring = YAML.safe_load(Rails.root.join("config/recurring.yml").read, aliases: true)

    %w[development production].each do |env|
      assert_equal({ "class" => "Game::ReconcileWalletsJob", "queue" => "default", "schedule" => "every day at 12:10am" },
        recurring.dig(env, "reconcile_wallets"), env)
    end
  end
end
