module Steam
  # Published when the store details of a page of kept apps are stored and the run's cursor moved past them (AD-10).
  # data = { import_run_id:, last_appid: }, the cursor after the page.
  class DetailsPageImported < RubyEventStore::Event
  end
end
