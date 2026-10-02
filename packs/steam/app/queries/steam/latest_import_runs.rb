module Steam
  # The latest import runs, the most recent first, for the back-office (AD-3).
  module LatestImportRuns
    LIMIT = 20

    def self.call(limit: LIMIT)
      ImportRun.latest_first.limit(limit).to_a
    end
  end
end
