module Steam
  # Published when an import run ends, completed or failed (AD-10).
  # data = { import_run_id:, status: } with status "completed" or "failed".
  class ImportRunFinished < RubyEventStore::Event
  end
end
