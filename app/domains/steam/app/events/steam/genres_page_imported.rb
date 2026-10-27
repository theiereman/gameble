module Steam
  # Published when the genres and credits of a page of detailed apps are stored and the run's cursor moved past them (AD-10).
  # data = { import_run_id:, last_appid: }, the cursor after the page.
  # No longer published: the genres step was removed on 2026-10-03. Kept so
  # the events of earlier runs still load.
  class GenresPageImported < RubyEventStore::Event
  end
end
