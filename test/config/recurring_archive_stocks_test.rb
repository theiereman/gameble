require "test_helper"

class RecurringArchiveStocksTest < ActiveSupport::TestCase
  test "the Archives' stocks are summed every hour in development and production" do
    recurring = YAML.safe_load(Rails.root.join("config/recurring.yml").read, aliases: true)

    %w[development production].each do |env|
      assert_equal({ "class" => "Game::ArchiveStocksJob", "queue" => "default", "schedule" => "every hour" },
        recurring.dig(env, "sum_archive_stocks"), env)
    end
  end
end
