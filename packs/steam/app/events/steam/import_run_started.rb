module Steam
  # Published when an administrator starts an import run, or resumes a failed
  # one from its cursor (AD-10). data = { import_run_id: }.
  class ImportRunStarted < RubyEventStore::Event
  end
end
