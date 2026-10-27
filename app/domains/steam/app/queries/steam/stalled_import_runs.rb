module Steam
  # Running import runs that have not moved for STALL_AFTER (AD-3, AD-19):
  # their page job was lost, as when the import worker is killed outright and
  # Solid Queue marks the job failed instead of handing it back.
  module StalledImportRuns
    STALL_AFTER = 10.minutes

    def self.call(now: Time.current)
      ImportRun.running.where(updated_at: ...(now - STALL_AFTER)).to_a
    end
  end
end
