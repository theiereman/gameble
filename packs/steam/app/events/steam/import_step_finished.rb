module Steam
  # Published when an import run finishes one of its steps (AD-10), before it
  # moves to the next step or, after the last one, completes.
  # data = { import_run_id:, step: }, the step finished.
  class ImportStepFinished < RubyEventStore::Event
  end
end
