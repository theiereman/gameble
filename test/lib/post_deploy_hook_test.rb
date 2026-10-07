require "test_helper"
require "open3"
require "socket"
require "tmpdir"

# The Kamal deploy hooks: pre-deploy refuses a deploy of an untagged commit
# (a destination is deployed from a published release only), and post-deploy
# (.kamal/hooks/post-deploy) posts a simplified changelog of the commits since
# the version last deployed (the tag deployed/<destination>, moved and pushed
# after each announcement) to the Discord webhook of
# config/discord_webhook.<destination>.key.
class PostDeployHookTest < ActiveSupport::TestCase
  PRE_DEPLOY = Rails.root.join(".kamal/hooks/pre-deploy")
  POST_DEPLOY = Rails.root.join(".kamal/hooks/post-deploy")

  # Loaded once: the hook defines DeployAnnouncement and runs nothing when it
  # is not the program.
  load POST_DEPLOY.to_s unless defined?(DeployAnnouncement)

  SUBJECTS = [
    "chore: initial",
    "feat(1.1): the first screen",
    "docs: notes",
    "feat(8.12): the booster island on the phone",
    "fix: the padlock icon gets its sheet description",
    "refactor: card views",
    "a commit without a type"
  ].freeze

  setup do
    @dir = Dir.mktmpdir
    @origin = File.join(@dir, "origin.git")
    @repo = File.join(@dir, "repo")
    git("init", "--quiet", "--bare", @origin, chdir: @dir)
    git("init", "--quiet", @repo, chdir: @dir)
    # The compare links read origin's fetch URL; the deployed tag is pushed to the local bare repository.
    git("remote", "add", "origin", "git@github.com:theiereman/gameble.git")
    git("remote", "set-url", "--push", "origin", @origin)
    git("config", "user.email", "test@example.com")
    git("config", "user.name", "Test")
    @versions = SUBJECTS.map { |subject| commit(subject) }
    FileUtils.mkdir_p(File.join(@repo, "config"))
    File.write(File.join(@repo, "config/deploy.staging.yml"), "env:\n  clear:\n    PUBLIC_URL: https://staging.example.com\n")
  end

  teardown do
    FileUtils.remove_entry(@dir)
  end

  test "the hooks are executable" do
    assert_predicate PRE_DEPLOY, :executable?
    assert_predicate POST_DEPLOY, :executable?
  end

  test "pre-deploy lets a tagged commit, a rollback and a deploy without destination through, refuses the rest" do
    git("tag", "v1.0.0", @versions[2])

    assert_predicate pre_deploy(version: @versions[2]), :success?
    assert_predicate pre_deploy(version: @versions.last, command: "rollback"), :success?
    assert_predicate pre_deploy(version: @versions.last, destination: nil), :success?

    output, status = pre_deploy(version: @versions.last, output: true)
    assert_not_predicate status, :success?
    assert_match(/staging is deployed from a published release only, and #{@versions.last} carries no tag/, output)

    output, status = pre_deploy(version: "#{@versions[2]}_uncommitted_abc123", output: true)
    assert_not_predicate status, :success?
    assert_match(/uncommitted changes/, output)
  end

  test "the first announced deploy lists the last commits, with the release link, and records the deployed tag" do
    git("tag", "v1.0.0", @versions[2])

    requests = with_webhook do |url|
      File.write(File.join(@repo, "config/discord_webhook.staging.key"), "#{url}\n")

      assert run_hook(version: @versions[2])
    end

    assert_equal 1, requests.size
    content = requests.first.fetch("content")
    assert_includes content, "🚀 **Gameble — nouvelle version en staging : v1.0.0**\n<https://staging.example.com>"
    assert_includes content, "Release `v1.0.0` (`#{@versions[2][0, 7]}`), par thomas, en 85 s"
    assert_includes content, "Première version annoncée : les 10 derniers commits."
    assert_includes content, "**✨ Nouveautés**\n• The first screen"
    assert_includes content, "_+ 2 commit(s) de maintenance (docs, chore…)_"
    assert_includes content, "<https://github.com/theiereman/gameble/releases/tag/v1.0.0>"
    assert_not_includes content, "/compare/"
    assert_equal({ "parse" => [] }, requests.first.fetch("allowed_mentions"))
    assert_equal @versions[2], deployed_tag(@repo)
    assert_equal @versions[2], deployed_tag(@origin)
  end

  test "the next release lists the commits since the deployed version, grouped and without maintenance, with a compare link" do
    git("tag", "v1.0.0", @versions[2])
    git("tag", "deployed/staging", @versions[2])
    git("tag", "v1.1.0", @versions.last)

    requests = with_webhook do |url|
      File.write(File.join(@repo, "config/discord_webhook.staging.key"), url)

      assert run_hook(version: "#{@versions.last}_uncommitted_abc123")
    end

    content = requests.first.fetch("content")
    assert_includes content, "nouvelle version en staging : v1.1.0**"
    assert_includes content, "Depuis `v1.0.0`, la dernière version déployée :\n\n**✨ Nouveautés**\n• The booster island on the phone\n\n**🐛 Corrections**\n• The padlock icon gets its sheet description\n\n**🔧 Autres changements**\n• A commit without a type\n• Card views"
    assert_not_includes content, "Notes"
    assert_not_includes content, "maintenance"
    assert_includes content, "<https://github.com/theiereman/gameble/releases/tag/v1.1.0>\n<https://github.com/theiereman/gameble/compare/v1.0.0...v1.1.0>"
    assert_equal @versions.last, deployed_tag(@repo)
    assert_equal @versions.last, deployed_tag(@origin)
  end

  test "the changelog starts at the deployed version, not at a release tag never deployed" do
    git("tag", "v1.0.0", @versions[1])
    git("tag", "deployed/staging", @versions[1])
    git("tag", "v1.1.0", @versions[4])
    git("tag", "v1.2.0", @versions.last)
    out = StringIO.new
    hook = DeployAnnouncement::Hook.new(env: kamal_env(version: @versions.last), root: @repo, out: out, err: StringIO.new)

    assert hook.run(dry_run: true)
    assert_includes out.string, "Depuis `v1.0.0`, la dernière version déployée :"
    assert_includes out.string, "**✨ Nouveautés**\n• The booster island on the phone\n\n**🐛 Corrections**\n• The padlock icon gets its sheet description"
    assert_includes out.string, "/compare/v1.0.0...v1.2.0>"
    assert_equal @versions[1], deployed_tag(@repo), "a dry run records nothing"
  end

  test "without a deployed tag, the nearest release below starts the changelog" do
    git("tag", "v1.0.0", @versions[2])
    git("tag", "v1.1.0", @versions.last)
    out = StringIO.new
    hook = DeployAnnouncement::Hook.new(env: kamal_env(version: @versions.last), root: @repo, out: out, err: StringIO.new)

    assert hook.run(dry_run: true)
    assert_includes out.string, "Depuis `v1.0.0`, la dernière version déployée :\n\n**✨ Nouveautés**\n• The booster island on the phone"
  end

  test "the highest tag of the commit names the release, and GitHub's actor is the performer" do
    git("tag", "v1.0.0", @versions[2])
    git("tag", "deployed/staging", @versions[2])
    git("tag", "v1.1.0-rc1", @versions.last)
    git("tag", "v1.1.0", @versions.last)
    out = StringIO.new
    env = kamal_env(version: @versions.last).merge("GITHUB_ACTOR" => "theiereman")
    hook = DeployAnnouncement::Hook.new(env: env, root: @repo, out: out, err: StringIO.new)

    assert hook.run(dry_run: true)
    assert_includes out.string, "staging : v1.1.0**"
    assert_includes out.string, "Release `v1.1.0` (`#{@versions.last[0, 7]}`), par theiereman"
    assert_includes out.string, "Depuis `v1.0.0`, la dernière version déployée :"
  end

  test "an untagged version (deployed with --skip-hooks) is announced by its sha" do
    git("tag", "deployed/staging", @versions[2])
    out = StringIO.new
    hook = DeployAnnouncement::Hook.new(env: kamal_env(version: @versions.last), root: @repo, out: out, err: StringIO.new)

    assert hook.run(dry_run: true)
    assert_includes out.string, "nouvelle version en staging : #{@versions.last[0, 7]}**"
    assert_includes out.string, "Version `#{@versions.last[0, 7]}`, sans tag, par thomas"
    assert_includes out.string, "Depuis `#{@versions[2][0, 7]}`, la dernière version déployée :\n\n**✨ Nouveautés**\n• The booster island on the phone"
    assert_includes out.string, "<https://github.com/theiereman/gameble/compare/#{@versions[2][0, 7]}...#{@versions.last[0, 7]}>"
    assert_not_includes out.string, "/releases/tag/"
  end

  test "a rollback lists the changes taken back and moves the deployed tag back" do
    git("tag", "v1.0.0", @versions[2])
    git("tag", "v1.1.0", @versions.last)
    git("tag", "deployed/staging", @versions.last)

    requests = with_webhook do |url|
      File.write(File.join(@repo, "config/discord_webhook.staging.key"), url)

      assert run_hook(version: @versions[2], command: "rollback")
    end

    content = requests.first.fetch("content")
    assert_includes content, "⏪ **Gameble — retour arrière en staging : v1.0.0**"
    assert_includes content, "**Changements retirés** (retour de `v1.1.0` à `v1.0.0`)\n\n**✨ Nouveautés**\n• The booster island on the phone"
    assert_includes content, "<https://github.com/theiereman/gameble/releases/tag/v1.0.0>\n<https://github.com/theiereman/gameble/compare/v1.0.0...v1.1.0>"
    assert_equal @versions[2], deployed_tag(@repo)
    assert_equal @versions[2], deployed_tag(@origin)
  end

  test "no announcement without a destination, for a redeploy, for the version already deployed, or without the webhook file" do
    out = StringIO.new
    hook = DeployAnnouncement::Hook.new(env: kamal_env(version: @versions.last).except("KAMAL_DESTINATION"), root: @repo, out: out, err: StringIO.new)
    assert_not hook.run
    assert_match(/no destination/, out.string)

    out = StringIO.new
    hook = DeployAnnouncement::Hook.new(env: kamal_env(version: @versions.last, command: "redeploy"), root: @repo, out: out, err: StringIO.new)
    assert_not hook.run(dry_run: true)
    assert_match(/a redeploy keeps the version/, out.string)

    git("tag", "deployed/staging", @versions.last)
    out = StringIO.new
    hook = DeployAnnouncement::Hook.new(env: kamal_env(version: @versions.last), root: @repo, out: out, err: StringIO.new)
    assert_not hook.run(dry_run: true)
    assert_match(/is the version already deployed/, out.string)

    out = StringIO.new
    hook = DeployAnnouncement::Hook.new(env: kamal_env(version: @versions[2]), root: @repo, out: out, err: StringIO.new)
    assert_not hook.run
    assert_match(/no .*discord_webhook\.staging\.key/, out.string)
    assert_equal @versions.last, deployed_tag(@repo)
  end

  test "a webhook that refuses the message fails the announcement, not the deploy, and keeps the deployed tag" do
    git("tag", "deployed/staging", @versions[2])
    File.write(File.join(@repo, "config/discord_webhook.staging.key"), "http://127.0.0.1:9/webhook")
    err = StringIO.new

    assert_not run_hook(version: @versions.last, err: err)
    assert_match(/post-deploy: Discord announcement failed/, err.string)
    assert_equal @versions[2], deployed_tag(@repo)
  end

  test "a long subject is cut at a word and a long message at Discord's limit" do
    change = DeployAnnouncement::Change.new("feat: #{(%w[word] * 60).join(' ')}")
    assert_operator change.line.length, :<=, 142
    assert_match(/\A• Word( word)+…\z/, change.line)

    changelog = DeployAnnouncement::Changelog.new(Array.new(20) { |i| "feat: change #{i}" })
    assert_includes changelog.to_markdown, "… et 5 autre(s)"

    webhook = DeployAnnouncement::Webhook.new("http://127.0.0.1:9/")
    cut = webhook.send(:cut, "x" * 3000)
    assert_equal 2000, cut.length
    assert_match(/liste coupée/, cut)
  end

  private
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

    def deployed_tag(repo)
      output, status = Open3.capture2e("git", "rev-parse", "--verify", "--quiet", "deployed/staging^{commit}", chdir: repo)
      status.success? ? output.strip : nil
    end

    def kamal_env(version:, command: "deploy", destination: "staging")
      { "KAMAL_DESTINATION" => destination, "KAMAL_VERSION" => version, "KAMAL_COMMAND" => command, "KAMAL_PERFORMER" => "thomas", "KAMAL_RUNTIME" => "85" }.compact
    end

    def pre_deploy(output: false, **env)
      result = Open3.capture2e(kamal_env(**env), PRE_DEPLOY.to_s, chdir: @repo, unsetenv_others: false)
      output ? result : result.last
    end

    def run_hook(version:, command: "deploy", err: StringIO.new)
      DeployAnnouncement::Hook.new(env: kamal_env(version: version, command: command), root: @repo, out: StringIO.new, err: err).run
    end

    # A webhook on a local port: answers 204 to every POST and yields its URL;
    # returns the JSON bodies received.
    def with_webhook
      server = TCPServer.new("127.0.0.1", 0)
      requests = []
      thread = Thread.new do
        while (socket = server.accept)
          headers = {}
          socket.gets
          while (line = socket.gets) && line != "\r\n"
            name, value = line.split(":", 2)
            headers[name.downcase] = value.strip
          end
          requests << JSON.parse(socket.read(headers["content-length"].to_i))
          socket.write("HTTP/1.1 204 No Content\r\nContent-Length: 0\r\nConnection: close\r\n\r\n")
          socket.close
        end
      rescue IOError
        nil
      end
      yield "http://127.0.0.1:#{server.addr[1]}/api/webhooks/1/token"
      requests
    ensure
      server&.close
      thread&.join(1)
    end
end
