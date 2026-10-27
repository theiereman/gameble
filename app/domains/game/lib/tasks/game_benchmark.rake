# Loaded again by test workers: the class stays outside lib/tasks so its constants are never redefined.
namespace :game do
  desc "Times pack opening on a 15,000-card season in its own database (RAILS_ENV=test); exits 1 when POST p95 >= 200 ms"
  task benchmark_open_pack: :environment do
    require_relative "../open_pack_benchmark"
    OpenPackBenchmark.new.run
  end
end
