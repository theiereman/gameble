module Steam
  # Reads one import run by database id, for the import job (AD-3). Nil when absent.
  module ImportRunById
    def self.call(id)
      ImportRun.find_by(id: id)
    end
  end
end
