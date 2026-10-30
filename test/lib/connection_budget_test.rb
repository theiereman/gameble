require "test_helper"
require "tmpdir"

# Every process of a deploy destination talks to its one Postgres: the
# connections their pools may open, counted from the committed configuration,
# stay under ConnectionBudget::LIMIT, and no pool is smaller than the threads
# that lease from it. Each role is counted under its deploy env alone.
class ConnectionBudgetTest < ActiveSupport::TestCase
  CONFIG_FILES = %w[database.yml puma.rb deploy.yml deploy.staging.yml deploy.production.yml queue.yml queue_import.yml recurring.yml].freeze
  STAGING = "ssh-staging.gameble.net".freeze

  teardown do
    FileUtils.remove_entry(@root) if @root
  end

  def budget(destination = "staging", root: Rails.root) = ConnectionBudget.new(destination:, root:)

  def figures(budget) = budget.processes.to_h { [ it.name, it.connections ] }

  def with_env(env)
    saved = env.keys.index_with { ENV[it] }
    env.each { |key, value| ENV[key] = value }
    yield
  ensure
    saved.each { |key, value| value.nil? ? ENV.delete(key) : ENV[key] = value }
  end

  def copied_root
    @root = Dir.mktmpdir
    FileUtils.mkdir_p(File.join(@root, "config"))
    CONFIG_FILES.each { FileUtils.cp(Rails.root.join("config", it), File.join(@root, "config", it)) }
    @root
  end

  def edit_yaml(name)
    path = File.join(@root, "config", name)
    yaml = YAML.safe_load_file(path, aliases: true)
    yield yaml
    File.write(path, YAML.dump(yaml))
  end

  test "staging's processes open 79 connections at most, under the limit, and every pool covers its threads" do
    staging = budget

    assert_equal({
      "web (#{STAGING}) Puma" => 17,
      "web (#{STAGING}) Solid Queue supervisor" => 5,
      "web (#{STAGING}) Solid Queue dispatcher" => 5,
      "web (#{STAGING}) Solid Queue worker (default)" => 14,
      "web (#{STAGING}) Solid Queue worker (share_images)" => 14,
      "web (#{STAGING}) Solid Queue scheduler" => 5,
      "import (#{STAGING}) Solid Queue supervisor" => 5,
      "import (#{STAGING}) Solid Queue worker (import)" => 14
    }, figures(staging))
    assert_equal({ "primary" => 3, "primary (reading)" => 3, "queue" => 5, "cache" => 3, "cable" => 3 }, staging.processes.first.pools)
    assert_equal 79, staging.total
    assert_not staging.over_limit?, "staging opens #{staging.total} connections, over the limit of #{ConnectionBudget::LIMIT}"
    assert_empty staging.undersized
  end

  test "the production destination counts one container per role on its host and stays under the limit" do
    production = budget("production")
    host = "ssh.gameble.net"

    assert_equal [ "web (#{host}) Puma", "web (#{host}) Solid Queue supervisor", "web (#{host}) Solid Queue dispatcher",
      "web (#{host}) Solid Queue worker (default)", "web (#{host}) Solid Queue worker (share_images)", "web (#{host}) Solid Queue scheduler",
      "import (#{host}) Solid Queue supervisor", "import (#{host}) Solid Queue worker (import)" ], production.processes.map(&:name)
    assert_equal 79, production.total
    assert_not production.over_limit?, "production opens #{production.total} connections, over the limit of #{ConnectionBudget::LIMIT}"
    assert_empty production.undersized
  end

  test "a variable set in the shell but not in the deploy files changes no count" do
    with_env("RAILS_MAX_THREADS" => "10", "JOB_CONCURRENCY" => "3", "WEB_CONCURRENCY" => "2", "MAX_THREADS" => "16") do
      assert_equal 79, budget.total
    end
  end

  test "JOB_CONCURRENCY 2 in the deploy env counts a second default worker in the web role, 93, over the limit" do
    root = copied_root
    edit_yaml("deploy.yml") { it["env"]["clear"]["JOB_CONCURRENCY"] = 2 }

    staging = budget(root:)
    workers = staging.processes.select { it.kind.start_with?("Solid Queue worker (default)") }

    assert_equal [ "Solid Queue worker (default) 1/2", "Solid Queue worker (default) 2/2" ], workers.map(&:kind)
    assert_equal 93, staging.total
    assert staging.over_limit?
  end

  test "RAILS_MAX_THREADS 10 in the deploy env goes over the limit and outgrows the queue pool" do
    root = copied_root
    edit_yaml("deploy.yml") { it["env"]["clear"]["RAILS_MAX_THREADS"] = 10 }

    staging = budget(root:)

    assert_equal 170, staging.total
    assert staging.over_limit?
    assert_includes staging.undersized, "web (#{STAGING}): the queue pool holds 5 connections, its Puma needs 10"
  end

  test "Puma's threads and workers come from config/puma.rb" do
    root = copied_root
    File.write(File.join(root, "config/puma.rb"), "threads 4, 4\nworkers 2\n")

    staging = budget(root:)

    assert_equal [ "Puma 1/2", "Puma 2/2" ], staging.processes.map(&:kind).grep(/Puma/)
    assert_includes staging.undersized, "web (#{STAGING}): the primary pool holds 3 connections, its Puma 1/2 needs 4"
  end

  test "the deploy env counts: JOB_CONCURRENCY 3 in config/deploy.yml makes 107, over the limit" do
    root = copied_root
    edit_yaml("deploy.yml") { it["env"]["clear"]["JOB_CONCURRENCY"] = 3 }

    with_env("JOB_CONCURRENCY" => "1") do
      staging = budget(root:)

      assert_equal 107, staging.total
      assert staging.over_limit?
      assert_equal "1", ENV["JOB_CONCURRENCY"], "the deploy env is laid over ENV while counting, then restored"
    end
  end

  test "WEB_CONCURRENCY 2 in the deploy env counts two Puma processes, 96, over the limit" do
    root = copied_root
    edit_yaml("deploy.yml") { it["env"]["clear"]["WEB_CONCURRENCY"] = 2 }

    staging = budget(root:)

    assert_equal [ "Puma 1/2", "Puma 2/2" ], staging.processes.map(&:kind).grep(/Puma/)
    assert_equal 96, staging.total
    assert staging.over_limit?
  end

  test "WEB_CONCURRENCY auto counts one Puma process per processor, as Puma does" do
    root = copied_root
    edit_yaml("deploy.yml") { it["env"]["clear"]["WEB_CONCURRENCY"] = "auto" }

    assert_equal [ Concurrent.available_processor_count.to_i, 1 ].max, budget(root:).processes.count { it.kind.start_with?("Puma") }
  end

  test "a WEB_CONCURRENCY Puma refuses names the role" do
    root = copied_root
    edit_yaml("deploy.yml") { it["env"]["clear"]["WEB_CONCURRENCY"] = "many" }

    error = assert_raises(ArgumentError) { budget(root:).processes }
    assert_match(/\Aweb: Puma refuses its configuration/, error.message)
  end

  test "a role's own env sizes that role's pools only" do
    root = copied_root
    edit_yaml("deploy.staging.yml") { it["servers"]["import"]["env"] = { "clear" => { "RAILS_MAX_THREADS" => 8 } } }

    staging = budget(root:)

    assert_equal({ "primary" => 8, "queue" => 5, "cache" => 8, "cable" => 8 }, staging.processes.last.pools)
    assert_equal 3, staging.processes.first.pools.fetch("primary")
    assert_equal 94, staging.total
  end

  test "a role env raising Puma's threads past the queue pool reports it undersized" do
    root = copied_root
    edit_yaml("deploy.staging.yml") do
      it["servers"]["web"] = { "hosts" => [ STAGING ], "env" => { "clear" => { "RAILS_MAX_THREADS" => 8 } } }
    end

    assert_equal [ "web (#{STAGING}): the queue pool holds 5 connections, its Puma needs 8" ], budget(root:).undersized
  end

  test "a 4-thread worker against a queue pool of 5 is reported undersized" do
    root = copied_root
    edit_yaml("queue.yml") { it["production"]["workers"].first["threads"] = 4 }

    undersized = budget(root:).undersized

    assert_includes undersized, "web (#{STAGING}): the queue pool holds 5 connections, its Solid Queue worker (default) needs 6"
    assert_includes undersized, "web (#{STAGING}): the primary pool holds 3 connections, its Solid Queue worker (default) needs 4"
  end

  test "a queue file without a dispatcher and a skipped recurring schedule count neither" do
    import = budget.processes.select { it.container.start_with?("import") }

    assert_equal [ "Solid Queue supervisor", "Solid Queue worker (import)" ], import.map(&:kind)
  end

  test "a role command that is neither Puma nor bin/jobs is refused" do
    root = copied_root
    edit_yaml("deploy.staging.yml") { it["servers"]["import"]["cmd"] = "bin/importer" }

    error = assert_raises(ArgumentError) { budget(root:).processes }
    assert_match(/\Aimport: cannot count the processes of `bin\/importer`/, error.message)
  end

  test "an unknown destination is refused" do
    assert_raises(ArgumentError) { budget("nowhere").processes }
  end
end
