require "test_helper"

# The import worker (AD-19, AD-21): one process, one thread, the import queue
# only; the jobs process leaves that queue alone.
class QueueConfigTest < ActiveSupport::TestCase
  def load_config(name)
    YAML.safe_load(ERB.new(Rails.root.join("config", name).read).result, aliases: true)
  end

  test "the import worker serves the import queue alone, with one process and one thread" do
    %w[development production].each do |env|
      workers = load_config("queue_import.yml").fetch(env).fetch("workers")

      assert_equal [ { "queues" => [ "import" ], "threads" => 1, "processes" => 1, "polling_interval" => 1 } ], workers, env
    end
  end

  test "the jobs process does not serve the import queue" do
    %w[development production].each do |env|
      load_config("queue.yml").fetch(env).fetch("workers").each do |worker|
        queues = Array(worker["queues"])

        assert_not_includes queues, "*", env
        assert_not_includes queues, "import", env
      end
    end
  end

  test "deployment runs the import worker as its own role, with the Steam key" do
    deploy = YAML.safe_load(Rails.root.join("config/deploy.yml").read, aliases: true)

    assert_equal "bin/jobs -c config/queue_import.yml --skip-recurring", deploy.dig("servers", "import", "cmd")
    assert_includes deploy.dig("env", "secret"), "STEAM_API_KEY"
  end
end
