require "shellwords"
require "puma/configuration"

class ConnectionBudget
  # Postgres' default max_connections (100) less its 3 superuser slots, with room for one-off sessions (console, db:prepare, a backup).
  LIMIT = 80

  READING = "primary (reading)".freeze
  PUMA_POOLS = [ "primary", READING, "queue", "cache", "cable" ].freeze
  WORKER_POOLS = %w[primary queue cache cable].freeze
  SOLID_QUEUE_POOLS = %w[queue].freeze

  # Solid Queue's own estimate for a worker: its threads, its polling thread and its heartbeat.
  WORKER_EXTRA_QUEUE_CONNECTIONS = 2
  DEFAULT_QUEUE_FILE = "config/queue.yml".freeze
  DEFAULT_RECURRING_FILE = "config/recurring.yml".freeze
  SOLID_QUEUE_FALLBACK = { "workers" => [ {} ], "dispatchers" => [ {} ] }.freeze
  COUNTED_ENV = %w[
    RAILS_MAX_THREADS JOB_CONCURRENCY WEB_CONCURRENCY PUMA_MAX_THREADS MAX_THREADS PUMA_MIN_THREADS MIN_THREADS
    SOLID_QUEUE_IN_PUMA SOLID_QUEUE_CONFIG SOLID_QUEUE_SKIP_RECURRING SOLID_QUEUE_RECURRING_SCHEDULE
  ].freeze

  ProcessBudget = Data.define(:container, :kind, :pools, :needs) do
    def name = "#{container} #{kind}"

    def connections = pools.values.sum

    def shortfalls = needs.select { |pool, needed| pools.fetch(pool) < needed }
  end

  Role = Data.define(:name, :hosts, :cmd, :env) do
    def containers = hosts.empty? ? [ name ] : hosts.map { "#{name} (#{it})" }
  end

  def initialize(destination:, root: Rails.root)
    @destination = destination.to_s
    @root = Pathname(root)
  end

  attr_reader :destination

  def processes
    @processes ||= roles.flat_map { |role| processes_of(role) }
  end

  def total = processes.sum(&:connections)

  def over_limit? = total > LIMIT

  def undersized
    shortfalls = processes.flat_map { |process| process.shortfalls.map { |pool, needed| [ process, pool, needed ] } }
    shortfalls.group_by { |process, pool, _| [ process.container, pool ] }.map do |(container, pool), entries|
      process, _, needed = entries.max_by(&:last)
      "#{container}: the #{pool} pool holds #{process.pools.fetch(pool)} connections, its #{process.kind} needs #{needed}"
    end
  end

  private

  def roles
    deploy = deploy_config
    shared_env = clear_env(deploy["env"])
    servers = deploy.fetch("servers") { raise ArgumentError, "the #{destination} destination declares no servers" }
    servers = { "web" => servers } if servers.is_a?(Array)

    servers.map do |name, settings|
      settings = { "hosts" => settings } unless settings.is_a?(Hash)
      Role.new(name:, hosts: Array(settings["hosts"]).map { host_name(it) }, cmd: settings["cmd"], env: shared_env.merge(clear_env(settings["env"])))
    end
  end

  def deploy_config
    destination_file = config_path("deploy.#{destination}.yml")
    raise ArgumentError, "unknown destination #{destination}: no #{destination_file}" unless destination_file.exist?

    deploy_yaml(config_path("deploy.yml")).deep_merge(deploy_yaml(destination_file))
  end

  def deploy_yaml(path) = YAML.safe_load(path.read, aliases: true) || {}

  def clear_env(env)
    return {} if env.blank?

    clear = env.key?("clear") || env.key?("secret") ? env["clear"] || {} : env
    clear.to_h { |key, value| [ key.to_s, value.to_s ] }
  end

  def host_name(host) = host.is_a?(Hash) ? host.keys.first.to_s : host.to_s

  def processes_of(role)
    kinds = with_env(role.env) { process_kinds_of(role) }
    role.containers.flat_map do |container|
      kinds.map { |kind| ProcessBudget.new(container:, **kind) }
    end
  end

  def process_kinds_of(role)
    sizes = pool_sizes
    command = role.cmd.to_s.shellsplit

    if puma?(command)
      puma_kinds(role, sizes) + (ENV["SOLID_QUEUE_IN_PUMA"] ? solid_queue_kinds(sizes, queue_file: default_queue_file, skip_recurring: skip_recurring_by_env?) : [])
    elsif jobs?(command)
      solid_queue_kinds(sizes, queue_file: queue_file_of(command) || default_queue_file, skip_recurring: skip_recurring?(command))
    else
      raise ArgumentError, "#{role.name}: cannot count the processes of `#{role.cmd}`, neither Puma nor bin/jobs"
    end
  end

  def puma?(command)
    command.empty? || command.include?("puma") || command.each_cons(2).any? { |program, verb| program.end_with?("rails") && %w[server s].include?(verb) }
  end

  def jobs?(command) = command.any? { it.end_with?("bin/jobs") }

  def queue_file_of(command)
    command.each_with_index do |argument, index|
      return command[index + 1] if %w[-c --config_file --config-file].include?(argument)
      return argument.split("=", 2).last if argument.start_with?("-c=", "--config_file=", "--config-file=")
    end
    nil
  end

  def skip_recurring?(command)
    command.intersect?(%w[--skip-recurring --skip_recurring]) || skip_recurring_by_env?
  end

  def skip_recurring_by_env? = ActiveModel::Type::Boolean.new.cast(ENV["SOLID_QUEUE_SKIP_RECURRING"]) || false

  def default_queue_file = ENV["SOLID_QUEUE_CONFIG"] || DEFAULT_QUEUE_FILE

  def puma_kinds(role, sizes)
    puma = puma_options(role)
    numbered("Puma", [ puma[:workers], 1 ].max).map do |kind|
      { kind:, pools: pools_of(PUMA_POOLS, sizes), needs: PUMA_POOLS.index_with(puma[:max_threads]) }
    end
  end

  def puma_options(role)
    Puma::Configuration.new({ config_files: [ config_path("puma.rb").to_s ] }, {}, ENV.to_h).tap(&:clamp).options
  rescue ArgumentError, TypeError => error
    raise ArgumentError, "#{role.name}: Puma refuses its configuration (#{error.message})"
  end

  def solid_queue_kinds(sizes, queue_file:, skip_recurring:)
    config = solid_queue_config(queue_file)
    queue_only = { pools: pools_of(SOLID_QUEUE_POOLS, sizes), needs: {} }

    [ { kind: "Solid Queue supervisor", **queue_only } ] +
      Array(config["dispatchers"]).map { { kind: "Solid Queue dispatcher", **queue_only } } +
      Array(config["workers"]).flat_map { worker_kinds(it, sizes) } +
      (!skip_recurring && scheduler?(config) ? [ { kind: "Solid Queue scheduler", **queue_only } ] : [])
  end

  def worker_kinds(worker, sizes)
    threads = Integer(worker.fetch("threads", SolidQueue::Configuration::WORKER_DEFAULTS[:threads]))
    needs = WORKER_POOLS.index_with(threads).merge("queue" => threads + WORKER_EXTRA_QUEUE_CONNECTIONS)
    queues = Array(worker.fetch("queues", SolidQueue::Configuration::WORKER_DEFAULTS[:queues])).join(", ")
    processes = Integer(worker.fetch("processes", SolidQueue::Configuration::WORKER_DEFAULTS[:processes]))

    numbered("Solid Queue worker (#{queues})", processes).map do |kind|
      { kind:, pools: pools_of(WORKER_POOLS, sizes), needs: }
    end
  end

  def numbered(kind, count) = count == 1 ? [ kind ] : (1..count).map { "#{kind} #{it}/#{count}" }

  def solid_queue_config(queue_file)
    config = production_section(erb_yaml(queue_file)).slice("workers", "dispatchers", "scheduler")
    config.empty? ? SOLID_QUEUE_FALLBACK : config
  end

  def scheduler?(config)
    recurring = production_section(erb_yaml(ENV["SOLID_QUEUE_RECURRING_SCHEDULE"] || DEFAULT_RECURRING_FILE))
    recurring.values.any? { it.is_a?(Hash) && it.key?("schedule") } || config.dig("scheduler", "dynamic_tasks_enabled") == true
  end

  def production_section(config) = config["production"] || config

  def erb_yaml(file)
    path = @root.join(file)
    path.exist? ? ActiveSupport::ConfigurationFile.parse(path).deep_stringify_keys : {}
  end

  def pool_sizes
    configurations = ActiveRecord::DatabaseConfigurations.new(ActiveSupport::ConfigurationFile.parse(config_path("database.yml")))
    configurations.configs_for(env_name: "production", include_hidden: true).to_h { [ it.name, it.max_connections ] }
  end

  def pools_of(pools, sizes) = pools.index_with { sizes.fetch(it == READING ? "primary" : it) }

  def config_path(name) = @root.join("config", name)

  def with_env(env)
    saved = (COUNTED_ENV | env.keys).index_with { ENV[it] }
    COUNTED_ENV.each { ENV.delete(it) }
    env.each { |key, value| ENV[key] = value }
    yield
  ensure
    saved&.each { |key, value| value.nil? ? ENV.delete(key) : ENV[key] = value }
  end
end
