module Steam
  # Published when an administrator promotes the ready import run's staged
  # cards into the draft season. data = { import_run_id: }.
  class ImportRunPromoted < RubyEventStore::Event
  end
end
