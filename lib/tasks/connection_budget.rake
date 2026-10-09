namespace :db do
  desc "Counts the connections every process of a deploy destination may open (default staging) against ConnectionBudget::LIMIT and the live Postgres allowance; exits 1 when a check fails"
  task :connection_budget, [ :destination ] => :environment do |_, args|
    budget = ConnectionBudget.new(destination: args[:destination].presence || "staging")
    say = ->(line) { puts "db:connection_budget: #{line}" }

    say.("#{budget.destination}, the connections each process's pools may open")
    budget.processes.each do |process|
      puts "  #{process.name}: #{process.connections} (#{process.pools.map { |pool, size| "#{pool} #{size}" }.join(", ")})"
    end
    say.("total #{budget.total}, limit #{ConnectionBudget::LIMIT}")

    allowance =
      begin
        max_connections, reserved = ActiveRecord::Base.with_connection do |connection|
          %w[max_connections superuser_reserved_connections].map { Integer(connection.select_value("SHOW #{it}")) }
        end
        say.("live allowance #{max_connections - reserved} (max_connections #{max_connections} less #{reserved} superuser_reserved_connections)")
        max_connections - reserved
      rescue ActiveRecord::ConnectionNotEstablished, ActiveRecord::NoDatabaseError, PG::ConnectionBad => error
        say.("live allowance unknown, Postgres did not answer (#{error.message.lines.first&.strip})")
        nil
      end

    failures = []
    failures << "total #{budget.total} is over the limit of #{ConnectionBudget::LIMIT}" if budget.over_limit?
    failures.concat(budget.undersized)
    failures << "total #{budget.total} is over the live allowance of #{allowance}" if allowance && budget.total > allowance
    abort failures.map { "db:connection_budget: #{it}" }.join("\n") if failures.any?
  end
end
