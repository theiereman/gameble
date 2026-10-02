module Steam
  # Published when the genres and credits of a page of detailed apps are stored and the run's cursor moved past them (AD-10).
  # data = { import_run_id:, last_appid: }, the cursor after the page.
  class GenresPageImported < RubyEventStore::Event
  end
end
