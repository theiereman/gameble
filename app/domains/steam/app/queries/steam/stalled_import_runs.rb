module Steam
  module StalledImportRuns
    STALL_AFTER = 10.minutes

    def self.call(now: Time.current)
      ImportRun.running.where(updated_at: ...(now - STALL_AFTER)).to_a
    end
  end
end
