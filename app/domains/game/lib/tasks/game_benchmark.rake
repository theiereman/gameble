# The task of app/domains/game/lib/open_pack_benchmark.rb. The class lives outside
# lib/tasks so that loading the tasks again (a test worker after
# test:prepare) never redefines its constants.
namespace :game do
  desc "Times pack opening on a 15,000-card season in its own database (RAILS_ENV=test); exits 1 when POST p95 >= 200 ms"
  task benchmark_open_pack: :environment do
    require_relative "../open_pack_benchmark"
    OpenPackBenchmark.new.run
  end
end
