require "test_helper"
require "open3"
require "tmpdir"

# bin/promote against a throwaway repository with a bare origin, and a stub
# gh that logs its calls and answers the candidate's commit statuses from a
# file.
class PromoteTest < ActiveSupport::TestCase
  PROMOTE = Rails.root.join("bin/promote")

  # Loaded once: the script defines Promotion and runs nothing when it is not
  # the program.
  load PROMOTE.to_s unless defined?(Promotion)

  setup do
    @dir = Dir.mktmpdir
    @origin = File.join(@dir, "origin.git")
    @repo = File.join(@dir, "repo")
    git("init", "--quiet", "--bare", "--initial-branch=main", @origin, chdir: @dir)
    git("init", "--quiet", "--initial-branch=develop", @repo, chdir: @dir)
    # Git's detached auto maintenance after a push or fetch writes into the repositories while teardown removes them.
    { "receive.autogc" => "false", "gc.auto" => "0", "maintenance.auto" => "false" }.each do |key, value|
      [ @origin, @repo ].each { |dir| git("config", key, value, chdir: dir) }
    end
    git("remote", "add", "origin", @origin)
    git("config", "user.email", "test@example.com")
    git("config", "user.name", "Test")
    @released = commit("feat: the first release")
    git("tag", "v0.9.0", @released)
    @candidate = commit("feat: the candidate")
    git("tag", "v1.0.0-rc.1", @candidate)
    git("push", "--quiet", "origin", "#{@released}:refs/heads/main", "develop", "--tags")
    @gh = stub_gh
    staging_status("success")
  end

  teardown do
    FileUtils.remove_entry(@dir)
  end

  test "bin/promote is executable" do
    assert_predicate PROMOTE, :executable?
  end

  test "a candidate that ran on staging moves main to its commit and is published as the release, notes since the previous one" do
    out = StringIO.new

    assert promote("v1.0.0-rc.1", out: out)
    assert_equal @candidate, origin_main
    assert_includes gh_calls, "api repos/{owner}/{repo}/commits/#{@candidate}/status"
    assert_includes gh_calls, "release create v1.0.0 --target #{@candidate} --title v1.0.0 --latest --generate-notes --notes-start-tag v0.9.0"
    assert_match(/v1\.0\.0 published on #{@candidate[0, 7]}/, out.string)
  end

  test "the first release has no previous release to start its notes from" do
    git("tag", "--delete", "v0.9.0")
    git("push", "--quiet", "origin", ":refs/tags/v0.9.0")

    assert promote("v1.0.0-rc.1")
    assert_includes gh_calls, "release create v1.0.0 --target #{@candidate} --title v1.0.0 --latest --generate-notes"
  end

  test "without --yes, only a yes pushes" do
    out = StringIO.new
    assert_not promote("v1.0.0-rc.1", yes: false, input: StringIO.new("\n"), out: out)
    assert_match(/Proceed\? \[y\/N\]/, out.string)
    assert_refused_untouched

    assert promote("v1.0.0-rc.1", yes: false, input: StringIO.new("y\n"))
    assert_equal @candidate, origin_main
  end

  test "a tag that is not a candidate is refused" do
    [ "v1.0.0", "v1.0.0-rc1", "v1.0.0-beta", "1.0.0-rc.1" ].each do |tag|
      assert_refusal(/is not a release candidate \(vX\.Y\.Z-rc\.N\)/, tag)
    end
    assert_refusal(/there is no tag v1\.0\.1-rc\.1/, "v1.0.1-rc.1")
  end

  test "a candidate whose commit is not on develop is refused" do
    git("checkout", "--quiet", "-b", "elsewhere")
    git("tag", "v1.1.0-rc.1", commit("feat: off develop"))
    git("push", "--quiet", "origin", "v1.1.0-rc.1")

    assert_refusal(/v1\.1\.0-rc\.1 is not on develop/, "v1.1.0-rc.1")
  end

  test "a candidate without a successful staging status is refused" do
    staging_status("failure")
    assert_refusal(/has no successful staging status/, "v1.0.0-rc.1")

    File.write(File.join(@dir, "status.json"), JSON.generate(statuses: [ { context: "ci", state: "success" } ]))
    assert_refusal(/has no successful staging status/, "v1.0.0-rc.1")
  end

  test "a release that already exists, as a tag or on GitHub, is refused" do
    FileUtils.touch(File.join(@dir, "release.published"))
    assert_refusal(/v1\.0\.0 already exists/, "v1.0.0-rc.1")

    FileUtils.rm(File.join(@dir, "release.published"))
    git("tag", "v1.0.0", @released)
    assert_refusal(/v1\.0\.0 already exists/, "v1.0.0-rc.1")
  end

  test "a main that is not an ancestor of the candidate is refused" do
    git("checkout", "--quiet", "-b", "hotfix", @released)
    hotfix = commit("fix: straight on main")
    git("push", "--quiet", "origin", "#{hotfix}:refs/heads/main")

    assert_refusal(/main is not an ancestor of v1\.0\.0-rc\.1/, "v1.0.0-rc.1", main: hotfix)
  end

  private
    def promote(tag, yes: true, input: StringIO.new, out: StringIO.new, err: StringIO.new)
      Promotion::Command.new(tag, yes: yes, root: @repo, gh: @gh, input: input, out: out, err: err).run
    end

    def assert_refusal(reason, tag, main: @released)
      err = StringIO.new
      assert_not promote(tag, err: err), "#{tag} is refused"
      assert_match reason, err.string
      assert_refused_untouched(main: main)
    end

    def assert_refused_untouched(main: @released)
      assert_equal main, origin_main
      assert_not(gh_calls.any? { |call| call.start_with?("release create") }, "no release is published")
    end

    def git(*args, chdir: @repo)
      output, status = Open3.capture2e("git", *args, chdir: chdir)
      flunk "git #{args.join(' ')}: #{output}" unless status.success?
      output.strip
    end

    def commit(subject)
      File.write(File.join(@repo, "f"), subject, mode: "a")
      git("add", "f")
      git("commit", "--quiet", "-m", subject)
      git("rev-parse", "HEAD")
    end

    def origin_main
      git("rev-parse", "main", chdir: @origin)
    end

    def staging_status(state)
      File.write(File.join(@dir, "status.json"), JSON.generate(statuses: [ { context: "staging", state: state } ]))
    end

    def gh_calls
      log = File.join(@dir, "gh.log")
      File.exist?(log) ? File.readlines(log, chomp: true) : []
    end

    def stub_gh
      path = File.join(@dir, "gh")
      File.write(path, <<~SH)
        #!/bin/sh
        printf '%s\\n' "$*" >> "#{@dir}/gh.log"
        case "$1 $2" in
          "api "*) cat "#{@dir}/status.json" ;;
          "release view") [ -f "#{@dir}/release.published" ] ;;
          "release create") exit 0 ;;
          *) exit 1 ;;
        esac
      SH
      File.chmod(0o755, path)
      path
    end
end
