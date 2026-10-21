module Steam
  # Published when an import run ends, ready for promotion or failed.
  # data = { import_run_id:, status: } with status "ready" or "failed".
  class ImportRunFinished < RubyEventStore::Event
  end
end
