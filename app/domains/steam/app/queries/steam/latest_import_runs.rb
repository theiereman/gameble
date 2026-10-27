module Steam
  module LatestImportRuns
    LIMIT = 20

    def self.call(limit: LIMIT)
      ImportRun.latest_first.limit(limit).to_a
    end
  end
end
