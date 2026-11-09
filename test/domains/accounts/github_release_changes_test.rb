require "test_helper"

class Accounts::GithubReleaseChangesTest < ActiveSupport::TestCase
  REPOSITORY = "/repos/theiereman/gameble".freeze

  setup do
    @stubs = Faraday::Adapter::Test::Stubs.new
    @adapter_was = Accounts::GithubReleaseChanges.connection_adapter
    Accounts::GithubReleaseChanges.connection_adapter = [ :test, @stubs ]
  end

  teardown { Accounts::GithubReleaseChanges.connection_adapter = @adapter_was }

  def tags(*names)
    @stubs.get("#{REPOSITORY}/tags") { [ 200, { "Content-Type" => "application/json" }, names.map { { name: it } }.to_json ] }
  end

  def compare(range, *subjects)
    commits = subjects.map { it.is_a?(Hash) ? it : { commit: { message: "#{it}\n\nBody line" } } }
    @stubs.get("#{REPOSITORY}/compare/#{range}") { [ 200, { "Content-Type" => "application/json" }, { commits: }.to_json ] }
  end

  def changes_for(name) = Accounts::GithubReleaseChanges.for(Accounts::ReleaseVersion.parse(name))

  test "a release's commits run from the release before it to its newest candidate" do
    tags("v1.3.0-rc.2", "v1.3.0-rc.10", "android-v1.2.0-3", "v1.2.1", "v1.2.1-rc.1", "v1.2.0", "deployed/production")
    compare("v1.2.1...v1.3.0-rc.10", "feat(booster): a capsule opens at once", "fix: cards are dealt face up")

    changes = changes_for("v1.3.0")

    assert_equal [ "v1.2.1", "v1.3.0-rc.10" ], [ changes.since, changes.head ]
    assert_equal [ [ "A capsule opens at once" ], [ "Cards are dealt face up" ] ], [ changes.features, changes.fixes ].map { it.map(&:subject) }
  end

  test "a change credits its author and co-authors, but not the owner, the assistant or a bot" do
    tags("v1.3.0-rc.1", "v1.2.1")
    message = "fix: cards are dealt face up\n\nCo-authored-by: Thomas <141121240+theiereman@users.noreply.github.com>\n" \
      "Co-authored-by: Tho <thoKling@users.noreply.github.com>\nCo-authored-by: Claude <noreply@anthropic.com>"
    compare("v1.2.1...v1.3.0-rc.1",
      { author: { login: "micilico", type: "User" }, commit: { message: } },
      { author: { login: "claude", type: "User" }, commit: { message: "feat: one" } },
      { author: { login: "dependabot[bot]", type: "Bot" }, commit: { message: "fix: bump" } },
      { author: { login: "theiereman", type: "User" }, commit: { message: "feat: two\n\nCo-authored-by: M <42+micilico@users.noreply.github.com>" } })

    changes = changes_for("v1.3.0")

    assert_equal [ [], %w[micilico] ], changes.features.map(&:credits)
    assert_equal [ %w[micilico thoKling], [] ], changes.fixes.map(&:credits)
  end

  test "a published release reads up to its own tag, one without a candidate up to develop" do
    tags("v1.3.0", "v1.3.0-rc.1", "v1.2.1")
    compare("v1.2.1...v1.3.0", "feat: one")
    assert_equal "v1.3.0", changes_for("v1.3.0").head

    @stubs = Faraday::Adapter::Test::Stubs.new
    Accounts::GithubReleaseChanges.connection_adapter = [ :test, @stubs ]
    tags("v1.3.0", "v1.2.1")
    compare("v1.3.0...develop", "fix: two")
    assert_equal [ "v1.3.0", "develop", [ "Two" ] ], changes_for("v1.4.0").then { [ it.since, it.head, it.fixes.map(&:subject) ] }
  end

  test "no release before it, or GitHub failing, gives nothing" do
    tags("v1.0.0-rc.1")
    assert_nil changes_for("v1.0.0")

    @stubs = Faraday::Adapter::Test::Stubs.new
    Accounts::GithubReleaseChanges.connection_adapter = [ :test, @stubs ]
    @stubs.get("#{REPOSITORY}/tags") { [ 503, {}, "" ] }
    assert_nil changes_for("v1.3.0")
  end
end
