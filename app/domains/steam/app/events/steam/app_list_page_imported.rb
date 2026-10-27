module Steam
  # Published when a page of the Steam app list is upserted and the run's
  # cursor moved past it (AD-10). data = { import_run_id:, last_appid: }, the
  # cursor after the page.
  class AppListPageImported < RubyEventStore::Event
  end
end
