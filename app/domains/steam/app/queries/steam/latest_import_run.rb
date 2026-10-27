module Steam
  module LatestImportRun
    def self.call
      ImportRun.latest_first.first
    end
  end
end
