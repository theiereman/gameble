require "test_helper"
require "open3"
require "tmpdir"

# script/backup/gameble-backup with stub docker and restic on PATH, which log
# their calls; restic saves the dump it reads as a snapshot.
class GamebleBackupTest < ActiveSupport::TestCase
  BACKUP = Rails.root.join("script/backup/gameble-backup")
  SNAPSHOT = "1a2b3c4d"

  setup do
    @dir = Dir.mktmpdir
    stub("docker", <<~SH)
      printf 'docker %s\\n' "$*" >> "#{@dir}/calls.log"
      [ -f "#{@dir}/docker.down" ] && { echo "Error response from daemon: No such container: gameble-db" >&2; exit 1; }
      printf 'PGDMP partial'
      [ -f "#{@dir}/docker.fails" ] && exit 1
      printf ' rest of the dump'
    SH
    stub("restic", <<~SH)
      printf 'restic %s\\n' "$*" >> "#{@dir}/calls.log"
      case "$1" in
        backup)
          cat > "#{@dir}/stdin"
          [ -f "#{@dir}/restic.fails" ] && { echo "Fatal: unable to open repository" >&2; exit 1; }
          echo "snapshot #{SNAPSHOT} saved"
          ;;
      esac
    SH
  end

  teardown do
    FileUtils.remove_entry(@dir)
  end

  test "the script is executable" do
    assert_predicate BACKUP, :executable?
  end

  test "a good run streams the dump into one tagged snapshot, then applies the retention" do
    output, status = backup

    assert_predicate status, :success?
    assert_equal [
      "docker exec gameble-db pg_dump --username=gameble --format=custom gameble_production",
      "restic backup --stdin --stdin-filename gameble_production.dump --tag gameble_production",
      "restic forget --tag gameble_production --keep-daily 7 --prune --max-unused 0"
    ], calls.sort
    assert_equal "restic forget --tag gameble_production --keep-daily 7 --prune --max-unused 0", calls.last
    assert_equal "PGDMP partial rest of the dump", File.read(File.join(@dir, "stdin"))
    assert_match(/snapshot #{SNAPSHOT} saved/, output)
  end

  test "a dump that dies mid-stream fails the run, forgets the snapshot it made and keeps the retention from running" do
    FileUtils.touch(File.join(@dir, "docker.fails"))

    output, status = backup

    assert_not_predicate status, :success?
    assert_includes calls, "restic forget #{SNAPSHOT}"
    assert_not calls.any? { it.include?("--keep-daily") }
    assert_match(/forgetting the incomplete snapshot #{SNAPSHOT}/, output)
  end

  test "a database that is down fails the run and keeps no snapshot" do
    FileUtils.touch(File.join(@dir, "docker.down"))

    output, status = backup

    assert_not_predicate status, :success?
    assert_equal "", File.read(File.join(@dir, "stdin"))
    assert_includes calls, "restic forget #{SNAPSHOT}"
    assert_not calls.any? { it.include?("--keep-daily") }
    assert_match(/No such container/, output)
  end

  test "a restic that cannot back up fails the run and forgets nothing" do
    FileUtils.touch(File.join(@dir, "restic.fails"))

    output, status = backup

    assert_not_predicate status, :success?
    assert_not calls.any? { it.start_with?("restic forget") }
    assert_match(/backup failed/, output)
  end

  private
    def backup
      Open3.capture2e({ "PATH" => "#{@dir}:#{ENV.fetch("PATH")}" }, BACKUP.to_s)
    end

    def calls
      File.readlines(File.join(@dir, "calls.log"), chomp: true)
    end

    def stub(name, body)
      path = File.join(@dir, name)
      File.write(path, "#!/bin/sh\n#{body}")
      File.chmod(0o755, path)
    end
end
