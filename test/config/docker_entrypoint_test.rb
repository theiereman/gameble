require "test_helper"
require "open3"

class DockerEntrypointTest < ActiveSupport::TestCase
  ENTRYPOINT = Rails.root.join("bin/docker-entrypoint").to_s

  def web_command = JSON.parse(Rails.root.join("Dockerfile").read[/^CMD (.+)$/, 1])

  def import_command(destination)
    YAML.safe_load(Rails.root.join("config/deploy.#{destination}.yml").read).dig("servers", "import", "cmd").split
  end

  def boot(command, rails_exit: 0)
    Dir.mktmpdir do |dir|
      log = File.join(dir, "boot.log")
      FileUtils.mkdir_p(File.join(dir, "bin"))
      { "rails" => "exit #{rails_exit}", "thrust" => "", "jobs" => "" }.each do |name, outcome|
        path = File.join(dir, "bin", name)
        File.write(path, "#!/bin/sh\necho \"#{name} $*\" >> \"#{log}\"\n#{outcome}\n")
        FileUtils.chmod(0o755, path)
      end
      _output, status = Open3.capture2e(ENTRYPOINT, *command, chdir: dir)
      [ status, File.exist?(log) ? File.readlines(log, chomp: true) : [] ]
    end
  end

  test "the web server boot prepares the database, then grants achievements from history and gives the market its first settings, before the server starts" do
    status, steps = boot(web_command)

    assert status.success?
    assert_equal [ "rails db:prepare game:backfill_achievements game:create_first_market_settings", "thrust #{web_command.drop(1).join(" ")}" ], steps
  end

  test "a failed database preparation, backfill or first settings keeps the server from starting" do
    status, steps = boot(web_command, rails_exit: 1)

    assert_not status.success?
    assert_equal [ "rails db:prepare game:backfill_achievements game:create_first_market_settings" ], steps
  end

  test "the import worker starts without preparing the database or granting achievements" do
    %w[staging production].each do |destination|
      command = import_command(destination)
      status, steps = boot(command)

      assert status.success?, destination
      assert_equal [ "jobs #{command.drop(1).join(" ")}" ], steps, destination
    end
  end
end
