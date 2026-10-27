module Steam
  # Published when an administrator abandons the latest failed import run, or discards the ready one
  # (AD-10). data = { import_run_id: }.
  class ImportRunAbandoned < RubyEventStore::Event
  end
end
