module Steam
  # Published when a page of ready apps is written into the draft season as cards and the run's cursor moved past them (AD-10).
  # data = { import_run_id:, last_appid: }, the cursor after the page.
  class CardsPageImported < RubyEventStore::Event
  end
end
