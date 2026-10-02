# The pack-opening benchmark (epic 3, R4; Done when 6): the spec asks the
# opening to answer within 200 ms at the 95th percentile. This task builds a
# 15,000-card published season and players with full banks in a database of
# its own, then times, in-process and without concurrency, the opening
# request (POST /en/packs, the gate), the result page that follows (GET) and
# the operation alone (Game::OpenPack), three times; it exits non-zero when
# the worst POST p95 reaches 200 ms. Never in CI.
#
#   RAILS_ENV=test bin/rails game:benchmark_open_pack
#
# It runs only in the test environment, on `gameble_benchmark` (the test
# configuration under that name): a database left by a crashed run is
# dropped first, then it is created, its schema loaded, and it is dropped at
# the end whatever happens. The connected database's name is checked before
# any write.
class OpenPackBenchmark
  DATABASE = "gameble_benchmark".freeze
  CARDS = 15_000
  TIMED = 1_000
  WARM_UP = 50
  OPENINGS_PER_PLAYER = 10
  HOLDINGS_PER_PLAYER = 300
  RUNS = 3
  LIMIT_MS = 200.0
  PERCENTILES = [ 50, 95, 99 ].freeze

  # The figures of one series: per operation, its time (ms), its queries and
  # the GC runs it saw.
  Series = Struct.new(:name, :times, :queries, :gc) do
    def self.empty(name) = new(name, [], [], [])

    def add(ms, queries, gc)
      times << ms
      self.queries << queries
      self.gc << gc
    end

    # Nearest rank: the smallest value with at least p % of the values at or
    # below it.
    def percentile(p)
      sorted = times.sort
      sorted.fetch([ (p / 100.0 * sorted.size).ceil, 1 ].max - 1)
    end

    def mean = times.sum / times.size

    def line
      format("%-26s n=%-5d mean %6.1f  p50 %6.1f  p95 %6.1f  p99 %6.1f  max %6.1f ms  GC %-4d  queries/op %.1f",
        name, times.size, mean, percentile(50), percentile(95), percentile(99), times.max, gc.sum,
        queries.sum.to_f / queries.size)
    end
  end

  def run
    refuse("runs only with RAILS_ENV=test") unless Rails.env.test?

    representative_settings
    begin
      prepare_database
      season_id = seed_catalog
      players = seed_players(season_id)
      sessions = sign_in(players.fetch(:http))
      results = Array.new(RUNS) do |run|
        measure_run(run, players.fetch(:http)[run], sessions[run], players.fetch(:direct)[run])
      end
      report(results)
    ensure
      drop_database
    end
  end

  private

  # --- Settings -------------------------------------------------------------

  # The settings closest to production that the test environment allows.
  def representative_settings
    # Production serves prebuilt assets: no build check on each page.
    ViteRuby.reload_with(auto_build: false)
    # rate_limit captures the controller's cache store when its class body
    # runs, so the store is set before the controllers load (eager_load!
    # below). Sign-ins do not use it (Rack::Attack counts in Rails.cache).
    # In memory: the Solid Cache write of production is not measured.
    loaded = ActionController::Base.descendants.map(&:name).grep(/\APacksController\z/)
    refuse("the packs controller loaded before its rate-limit store was set") if loaded.any?
    @rate_limit_store = ActiveSupport::Cache::MemoryStore.new
    ActionController::Base.cache_store = @rate_limit_store

    Rails.application.eager_load!
    Rails.logger.level = :info
    ActiveRecord::Base.logger&.level = :info

    @queries = 0
    ActiveSupport::Notifications.subscribe("sql.active_record") do |*, payload|
      @queries += 1 unless payload[:name] == "SCHEMA" || payload[:cached]
    end
  end

  # --- Database -------------------------------------------------------------

  def db_config
    @db_config ||= begin
      test = ActiveRecord::Base.configurations.configs_for(env_name: "test", name: "primary")
      ActiveRecord::DatabaseConfigurations::HashConfig.new("test", "benchmark", test.configuration_hash.merge(database: DATABASE))
    end
  end

  def prepare_database
    # Rails unpacks DATABASE_URL into the config before this runs, so the
    # environment variable itself is what must be refused: it could point
    # the drop and create at another server.
    refuse("refuses DATABASE_URL; set DB_HOST, DB_PORT, DB_USER, DB_PASSWORD") if ENV["DATABASE_URL"].present?
    refuse("refuses database #{db_config.database}") unless db_config.database == DATABASE

    # A database left by a crashed run goes first.
    ActiveRecord::Tasks::DatabaseTasks.drop(db_config)
    ActiveRecord::Tasks::DatabaseTasks.create(db_config)
    ActiveRecord::Base.establish_connection(db_config)
    check_database!
    ActiveRecord::Tasks::DatabaseTasks.load_schema(db_config, :ruby, Rails.root.join("db/schema.rb").to_s)
    check_database!
  end

  def drop_database
    ActiveRecord::Base.connection_handler.clear_all_connections!(:all)
    return if ENV["DATABASE_URL"].present? || db_config.database != DATABASE

    ActiveRecord::Tasks::DatabaseTasks.drop(db_config)
  end

  # Every write goes to the benchmark's own database, or nothing is written.
  def check_database!
    connected = ActiveRecord::Base.with_connection { |connection| connection.select_value("SELECT current_database()") }
    refuse("connected to #{connected}, not #{DATABASE}") unless connected == DATABASE
  end

  # --- Seeding --------------------------------------------------------------

  # A published season of CARDS cards, all five tiers filled by the
  # publication's cut (Catalog::RarityThresholds), numbered above any other.
  def seed_catalog
    check_database!
    random = Random.new(9)
    now = Time.current
    number = (Catalog::Season.maximum(:number) || 0) + 1
    season_id = Catalog::Season.insert_all!([ { number:, status: "published", published_at: now } ], returning: :id).rows.flatten.sole

    release_dates = Array.new(CARDS) { Date.new(1990, 1, 1) + random.rand(13_000) }
    card_ids = Catalog::Card.insert_all!(Array.new(CARDS) do |index|
      { source_key: "benchmark:#{index}", slug: "benchmark-game-#{index}", release_date: release_dates[index],
        image_url: "https://images.example.test/#{index}.jpg", store_url: "https://store.example.test/#{index}",
        publisher: "Publisher #{index % 900}", genres: [ "action" ] }
    end, returning: :id).rows.flatten
    Catalog::CardText.insert_all!(card_ids.each_with_index.flat_map do |card_id, index|
      %w[en fr].map { |locale| { card_id:, locale:, title: "Benchmark game #{index} (#{locale})", short_description: "A game." } }
    end)

    scores = Array.new(CARDS) { |index| index + random.rand }.shuffle(random:)
    tiers = Catalog::RarityThresholds.tiers(scores) || refuse("the cut left a tier empty")
    Catalog::CardSeason.insert_all!(card_ids.each_with_index.map do |card_id, index|
      { card_id:, season_id:, prestige_score: scores[index], rating: random.rand(0..100), rarity: tiers[index],
        dust_tier: Catalog::Dust.level_for(release_dates[index], on: now.to_date) }
    end)
    season_id
  end

  # Players in separate groups per series and run, each with a full bank
  # (Game::FillBank) and HOLDINGS_PER_PLAYER holdings.
  def seed_players(season_id)
    check_database!
    per_group = ((TIMED + WARM_UP) / OPENINGS_PER_PLAYER.to_f).ceil
    groups = { http: [], direct: [] }
    serial = 0
    RUNS.times do
      groups.each_value do |runs|
        rows = Array.new(per_group) do
          serial += 1
          { steam_id: format("7656119%010d", serial), token: SecureRandom.base58(24), role: "player" }
        end
        ids = Accounts::Player.insert_all!(rows, returning: :id).rows.flatten
        runs << Accounts::Player.where(id: ids).order(:id).to_a
      end
    end

    players = groups.values.flatten(2)
    card_season_ids = Catalog::CardSeason.where(season_id:).pluck(:id)
    random = Random.new(11)
    players.each do |player|
      Game::FillBank.new.call(player:).value! == Game::Pack::BANK_SIZE || refuse("player #{player.id}: bank not filled")
    end
    now = Time.current
    players.each_slice(50) do |slice|
      Game::Holding.insert_all!(slice.flat_map do |player|
        card_season_ids.sample(HOLDINGS_PER_PLAYER, random:).map do |card_season_id|
          { player_id: player.id, card_season_id:, quantity: random.rand(1..4), created_at: now, updated_at: now }
        end
      end)
    end
    ActiveRecord::Base.with_connection { |connection| connection.execute("VACUUM ANALYZE") }
    groups
  end

  # --- Sign-in --------------------------------------------------------------

  # One integration session per HTTP player, signed in through OmniAuth's
  # test mode (as pages_controller_test.rb does), each checked.
  def sign_in(runs)
    require "action_dispatch/testing/integration"
    OmniAuth.config.test_mode = true
    runs.map do |players|
      players.map do |player|
        session = ActionDispatch::Integration::Session.new(Rails.application)
        OmniAuth.config.mock_auth[:steam] = OmniAuth::AuthHash.new(provider: "steam",
          uid: "https://steamcommunity.com/openid/id/#{player.steam_id}")
        session.post "/auth/steam", params: { origin: "/en" }
        session.follow_redirect!
        refuse("player #{player.id}: sign-in failed") unless session.request.session[:player_id] == player.id
        session
      end
    end
  ensure
    OmniAuth.config.mock_auth.delete(:steam)
    OmniAuth.config.test_mode = false
  end

  # --- Measure --------------------------------------------------------------

  def measure_run(run, http_players, sessions, direct_players)
    check_database!
    Game::DrawPool.reset!
    cold_ms, = timed { Game::DrawPool.current }

    post = Series.empty("POST /en/packs")
    get = Series.empty("GET /en/packs/:token")
    direct = Series.empty("Game::OpenPack")
    posts_by_player = Hash.new(0)

    (WARM_UP + TIMED).times do |index|
      keep = index >= WARM_UP
      player_index, = index.divmod(OPENINGS_PER_PLAYER)

      session = sessions.fetch(player_index)
      location = open_over_http(session, post, keep)
      posts_by_player[http_players.fetch(player_index).id] += 1
      read_over_http(session, location, get, keep)

      open_directly(direct_players.fetch(player_index), direct, keep)
    end
    check_rate_limit_ran(posts_by_player)

    { run:, cold_ms:, series: [ post, get, direct ] }
  end

  def open_over_http(session, series, keep)
    ms, queries, gc = timed { session.post "/en/packs" }
    location = session.response.location.to_s
    unless session.response.status == 303 && location.match?(%r{/packs/})
      refuse("an opening over HTTP failed: #{session.response.status} to #{location.inspect}")
    end
    series.add(ms, queries, gc) if keep
    location
  end

  def read_over_http(session, location, series, keep)
    ms, queries, gc = timed { session.get location }
    refuse("the result page answered #{session.response.status}") unless session.response.status == 200
    series.add(ms, queries, gc) if keep
  end

  def open_directly(player, series, keep)
    result = nil
    ms, queries, gc = timed { result = Game::OpenPack.new.call(player:) }
    refuse("a direct opening failed: #{result.failure.inspect}") unless result.success?
    series.add(ms, queries, gc) if keep
  end

  # The rate limit ran on the in-memory store: its count per player is the
  # number of POSTs.
  def check_rate_limit_ran(posts_by_player)
    posts_by_player.each do |player_id, count|
      counted = @rate_limit_store.read("rate-limit:packs:#{player_id}", raw: true).to_i
      refuse("the rate limit counted #{counted} openings of #{count} for player #{player_id}") unless counted == count
    end
  end

  # [ms, queries, GC runs] of the block, timed alone.
  def timed
    queries = @queries
    gc = GC.count
    started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    yield
    elapsed = (Process.clock_gettime(Process::CLOCK_MONOTONIC) - started) * 1000.0
    [ elapsed, @queries - queries, GC.count - gc ]
  end

  # --- Report ---------------------------------------------------------------

  def report(results)
    puts machine_line
    puts "#{CARDS} cards; #{WARM_UP} warm-up openings discarded per series; in-process, no concurrency, dev machine: a lower bound for production"
    results.each do |result|
      puts
      puts format("Run %d — cold DrawPool build on %d rows: %.1f ms", result.fetch(:run) + 1, CARDS, result.fetch(:cold_ms))
      result.fetch(:series).each { |series| puts "  #{series.line}" }
    end

    worst = results.map { |result| result.fetch(:series).first.percentile(95) }.max
    puts
    puts format("Worst POST p95 over %d runs: %.1f ms (limit %d ms)", RUNS, worst, LIMIT_MS)
    exit(1) if worst >= LIMIT_MS
  end

  def machine_line
    yjit = defined?(RubyVM::YJIT) && RubyVM::YJIT.enabled? ? "on" : "off"
    postgres = ActiveRecord::Base.with_connection { |connection| connection.select_value("SHOW server_version") }
    cpu = File.exist?("/proc/cpuinfo") ? File.foreach("/proc/cpuinfo").grep(/\Amodel name/).first.to_s.split(":", 2).last.to_s.strip : "?"
    format("Machine: Ruby %s, YJIT %s; PostgreSQL %s at %s:%s; %s, %d CPUs", RUBY_VERSION, yjit, postgres,
      db_config.host, db_config.configuration_hash[:port], cpu, Etc.nprocessors)
  end

  def refuse(message)
    abort "game:benchmark_open_pack: #{message}"
  end
end

namespace :game do
  desc "Times pack opening on a 15,000-card season in its own database (RAILS_ENV=test); exits 1 when POST p95 >= 200 ms"
  task benchmark_open_pack: :environment do
    OpenPackBenchmark.new.run
  end
end
