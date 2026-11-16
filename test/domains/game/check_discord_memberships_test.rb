require "test_helper"

class Game::CheckDiscordMembershipsTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  NOW = Time.utc(2026, 11, 16, 12, 0)
  TOKEN = "bot-secret-token".freeze

  UNKNOWN_MEMBER = '{"code":10007}'.freeze

  setup do
    @player = accounts_players(:player)
    @other = accounts_players(:moderator)
    @requests = []
  end

  def link(player, uid) = Accounts::Identity.create!(player:, provider: "discord", uid:)

  def client(token: TOKEN, guild_id: "guild-1", &answers)
    stubs = Faraday::Adapter::Test::Stubs.new
    stubs.get(%r{/members/(.+)\z}) do |env|
      uid = env.url.path.split("/").last
      @requests << uid
      answers.call(uid)
    end
    Accounts::DiscordClient.adapter = [ :test, stubs ]
    Accounts::DiscordClient.new(token:, guild_id:)
  end

  teardown { Accounts::DiscordClient.adapter = [ :test, Faraday::Adapter::Test::Stubs.new ] }

  def run_job(client) = Game::CheckDiscordMembershipsJob.perform_now(client:, now: NOW)
  def state(player = @player) = Game::PlayerState.find_by(player_id: player.id)
  def events = Rails.configuration.event_store.read.of_type(Game::DiscordMemberFound).count
  def metric(player = @player) = Game::AchievementProgress.call(player, [ :discord_member ]).fetch(:discord_member)

  test "a member is marked, an event is published and the achievement is granted" do
    link(@player, "d-1")

    assert_difference -> { events }, 1 do
      perform_enqueued_jobs { run_job(client { [ 200, {}, "{}" ] }) }
    end

    assert_equal [ NOW, NOW ], [ state.discord_member_at, state.discord_checked_at ]
    assert_equal 1, metric
    assert Game::AchievementUnlock.exists?(player_id: @player.id, achievement: "discord_member")
  end

  test "a player who is not a member only gets a new checked time" do
    link(@player, "d-1")

    assert_no_difference -> { events } do
      run_job(client { [ 404, {}, UNKNOWN_MEMBER ] })
    end

    assert_nil state.discord_member_at
    assert_equal NOW, state.discord_checked_at
    assert_equal 0, metric
  end

  test "a player with no Discord account, a marked one and a removed one are never asked" do
    link(@other, "d-marked")
    Game::MarkDiscordMember.new.call(player: @other, member: true, now: NOW - 1.day).value!
    banned = accounts_players(:banned)
    link(banned, "d-banned")

    run_job(client { [ 200, {}, "{}" ] })

    assert_empty @requests
  end

  test "without a token or a guild id the job asks nothing" do
    link(@player, "d-1")

    run_job(client(token: nil) { [ 200, {}, "{}" ] })
    run_job(client(guild_id: "") { [ 200, {}, "{}" ] })

    assert_empty @requests
    assert_nil state&.discord_checked_at
  end

  test "a rate limit stops the run and marks nothing" do
    link(@player, "d-1")
    link(@other, "d-2")

    run_job(client { [ 429, {}, "{}" ] })

    assert_equal 1, @requests.size
    assert_nil state&.discord_checked_at
    assert_nil state(@other)&.discord_checked_at
  end

  test "a 404 for an unknown server is an error, not a missing member" do
    link(@player, "d-1")

    run_job(client { [ 404, {}, '{"code":10004}' ] })

    assert_nil state&.discord_member_at
  end

  test "another failure is reported, leaves the player unmarked and the run goes on" do
    link(@player, "d-1")
    link(@other, "d-2")
    reported = []
    subscriber = Struct.new(:reported) { def report(error, **) = reported << error }.new(reported)
    Rails.error.subscribe(subscriber)

    run_job(client { |uid| uid == "d-1" ? [ 503, {}, "{}" ] : [ 200, {}, "{}" ] })

    assert_equal 1, reported.size
    assert_nil state.discord_member_at
    assert_not_nil state(@other).discord_member_at
  ensure
    Rails.error.unsubscribe(subscriber)
  end

  test "the least recently checked player is asked first" do
    link(@player, "d-1")
    link(@other, "d-2")
    Game::MarkDiscordMember.new.call(player: @player, member: false, now: NOW - 1.hour).value!

    run_job(client { [ 404, {}, UNKNOWN_MEMBER ] })

    assert_equal %w[d-2 d-1], @requests
  end

  test "the batch is bounded" do
    link(@player, "d-1")
    link(@other, "d-2")
    stub_const_batch(1) { run_job(client { [ 404, {}, UNKNOWN_MEMBER ] }) }

    assert_equal 1, @requests.size
  end

  def stub_const_batch(size)
    original = Game::CheckDiscordMembershipsJob::BATCH_SIZE
    Game::CheckDiscordMembershipsJob.send(:remove_const, :BATCH_SIZE)
    Game::CheckDiscordMembershipsJob.const_set(:BATCH_SIZE, size)
    yield
  ensure
    Game::CheckDiscordMembershipsJob.send(:remove_const, :BATCH_SIZE)
    Game::CheckDiscordMembershipsJob.const_set(:BATCH_SIZE, original)
  end

  test "the operation records a check, marks a member once and publishes once" do
    assert_difference -> { events }, 1 do
      assert Game::MarkDiscordMember.new.call(player: @player, member: true, now: NOW).value!
      assert_not Game::MarkDiscordMember.new.call(player: @player, member: true, now: NOW + 1.hour).value!
    end

    assert_equal [ NOW, NOW ], [ state.discord_member_at, state.discord_checked_at ]
  end

  test "the operation refuses a banned player" do
    assert_equal :player_required, Game::MarkDiscordMember.new.call(player: accounts_players(:banned), member: true).failure
  end

  test "the client never lets the token out of an error" do
    adapter = Faraday::Adapter::Test::Stubs.new
    adapter.get(/members/) { raise Faraday::ConnectionFailed, "failed with #{TOKEN} and #{CGI.escape(TOKEN)}" }
    Accounts::DiscordClient.adapter = [ :test, adapter ]

    error = assert_raises(Accounts::DiscordClient::Error) { Accounts::DiscordClient.new(token: TOKEN, guild_id: "g").member?("d-1") }

    assert_not_includes error.message, TOKEN
    assert_includes error.message, "[FILTERED]"
    assert_not_includes Accounts::DiscordClient.new(token: TOKEN, guild_id: "g").inspect, TOKEN
  end

  test "the client sends the bot token and reads membership from the status" do
    seen = nil
    adapter = Faraday::Adapter::Test::Stubs.new
    adapter.get("/api/v10/guilds/g/members/d-1") { |env| seen = env.request_headers["Authorization"]; [ 200, {}, "{}" ] }
    Accounts::DiscordClient.adapter = [ :test, adapter ]

    assert Accounts::DiscordClient.new(token: TOKEN, guild_id: "g").member?("d-1")
    assert_equal "Bot #{TOKEN}", seen
  end

  test "the catalogue entry reads the marker" do
    assert Game::Achievements.find(:discord_member).met?(discord_member: 1)
    assert_not Game::Achievements.find(:discord_member).met?(discord_member: 0)
  end
end
