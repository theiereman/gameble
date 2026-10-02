module Steam
  # The latest import run, or nil (AD-3, AD-19).
  module LatestImportRun
    def self.call
      ImportRun.latest_first.first
    end
  end
end
