require "test_helper"

# The import worker: one process, one thread, the import queue
# only; the jobs process leaves that queue alone, and dispatches and serves
# the queues of the other jobs, the share image renders with one worker of
# one thread.
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

  test "the jobs process dispatches and serves the default queue, the bank healing's and the stalled-import recovery's" do
    recurring = YAML.safe_load(Rails.root.join("config/recurring.yml").read, aliases: true)
    queues = [ "default", Game::HealBanksJob.new.queue_name, Steam::RecoverStalledImportsJob.new.queue_name ]

    %w[development production].each do |env|
      config = load_config("queue.yml").fetch(env)
      served = config.fetch("workers").flat_map { Array(it["queues"]) }

      assert_not_empty config.fetch("dispatchers"), env
      (queues + [ recurring.fetch(env).fetch("recover_stalled_imports").fetch("queue") ]).each { assert_includes served, it, env }
    end
  end

  test "the share image renders run on their own worker, one process of one thread, in every environment" do
    assert_equal "share_images", CardShareImageJob.new.queue_name

    %w[development test production].each do |env|
      workers = load_config("queue.yml").fetch(env).fetch("workers")

      assert_equal [ { "queues" => [ "share_images" ], "threads" => 1, "processes" => 1, "polling_interval" => 1 } ],
        workers.select { Array(it["queues"]).include?("share_images") }, env
      assert_not_includes workers.find { Array(it["queues"]).include?("default") }.fetch("queues"), "share_images", env
    end
  end

  test "the retention job runs every day in development and production" do
    recurring = YAML.safe_load(Rails.root.join("config/recurring.yml").read, aliases: true)

    %w[development production].each do |env|
      assert_equal({ "class" => "Accounts::ApplyRetentionJob", "queue" => "default", "schedule" => "every day at 4am" },
        recurring.dig(env, "apply_retention"), env)
    end
  end

  test "production containers and its proxy log to journald, with no size limit journald would refuse; staging keeps the default" do
    production = YAML.safe_load(Rails.root.join("config/deploy.production.yml").read, aliases: true)
    staging = YAML.safe_load(Rails.root.join("config/deploy.staging.yml").read, aliases: true)
    shared = YAML.safe_load(Rails.root.join("config/deploy.yml").read, aliases: true)

    assert_equal({ "driver" => "journald" }, production["logging"])
    assert_equal({ "log_max_size" => "", "options" => { "log-driver" => "journald" } }, production.dig("proxy", "run"))
    assert_nil staging["logging"]
    assert_nil staging.dig("proxy", "run")
    assert_nil shared["logging"]
  end

  test "each destination runs the import worker as its own role, with the Steam key" do
    shared = YAML.safe_load(Rails.root.join("config/deploy.yml").read, aliases: true)
    assert_includes shared.dig("env", "secret"), "STEAM_API_KEY"

    %w[staging production].each do |destination|
      deploy = YAML.safe_load(Rails.root.join("config/deploy.#{destination}.yml").read, aliases: true)
      assert_equal "bin/jobs -c config/queue_import.yml --skip-recurring", deploy.dig("servers", "import", "cmd"), destination
    end
  end
end
