module Steam
  module UnfinishedImportRun
    def self.call
      run = ImportRun.where.not(status: :abandoned).latest_first.first
      run unless run.nil? || run.completed? || run.promoted?
    end
  end
end
