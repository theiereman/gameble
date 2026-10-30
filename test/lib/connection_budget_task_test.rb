require "test_helper"
require_relative "../support/rake_tasks"
require "tmpdir"

# db:connection_budget[destination] prints what ConnectionBudget counts and
# compares it with the live Postgres allowance; it runs in a deployed
# container, so the image keeps the deploy files it reads.
class ConnectionBudgetTaskTest < ActiveSupport::TestCase
  include RakeTasks

  setup { rake_task("db:connection_budget") }

  def run_task(destination = "staging")
    rake_task("db:connection_budget").execute(Rake::TaskArguments.new([ :destination ], [ destination ]))
  end

  test "prints every process, the total, the limit and the live allowance for staging, and exits normally" do
    output, = capture_io { run_task }

    assert_includes output, "  web (ssh-staging.gameble.net) Puma: 17 (primary 3, primary (reading) 3, queue 5, cache 3, cable 3)\n"
    assert_includes output, "  web (ssh-staging.gameble.net) Solid Queue worker (share_images): 14 (primary 3, queue 5, cache 3, cable 3)\n"
    assert_includes output, "  import (ssh-staging.gameble.net) Solid Queue worker (import): 14 (primary 3, queue 5, cache 3, cable 3)\n"
    assert_includes output, "db:connection_budget: total 79, limit 80\n"
    assert_match(/^db:connection_budget: live allowance (\d+) \(max_connections \d+ less \d+ superuser_reserved_connections\)$/, output)
  end

  test "says the live allowance is unknown when Postgres does not answer, and judges on the limit alone" do
    ActiveRecord::Base.singleton_class.define_method(:with_connection) { |*| raise ActiveRecord::ConnectionNotEstablished, "connection refused" }

    output, = capture_io { run_task }

    assert_includes output, "db:connection_budget: live allowance unknown, Postgres did not answer (connection refused)\n"
  ensure
    ActiveRecord::Base.singleton_class.remove_method(:with_connection)
  end

  test "aborts with every failed check" do
    root = Dir.mktmpdir
    FileUtils.cp_r(Rails.root.join("config"), root)
    deploy = YAML.safe_load_file(File.join(root, "config/deploy.yml"), aliases: true)
    deploy["env"]["clear"]["RAILS_MAX_THREADS"] = 10
    File.write(File.join(root, "config/deploy.yml"), YAML.dump(deploy))
    counted = ConnectionBudget.method(:new)
    ConnectionBudget.singleton_class.define_method(:new) { |**options| counted.call(**options, root:) }

    _, error = capture_io { assert_raises(SystemExit) { run_task } }

    assert_includes error, "db:connection_budget: total 170 is over the limit of 80\n"
    assert_includes error, "db:connection_budget: web (ssh-staging.gameble.net): the queue pool holds 5 connections, its Puma needs 10\n"
  ensure
    ConnectionBudget.singleton_class.remove_method(:new)
    FileUtils.remove_entry(root)
  end

  test "the image keeps the deploy files the task reads" do
    ignored = Rails.root.join(".dockerignore").readlines(chomp: true).map(&:strip).reject { it.empty? || it.start_with?("#", "!") }

    %w[config/deploy.yml config/deploy.staging.yml config/deploy.production.yml].each do |file|
      assert ignored.none? { File.fnmatch?(it.delete_prefix("/"), file, File::FNM_PATHNAME) }, "#{file} is left out of the image by .dockerignore"
    end
  end
end
