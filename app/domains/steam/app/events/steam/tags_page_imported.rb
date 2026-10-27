module Steam
  # Published when the English names of Steam's store tags are upserted (the tags step's one page) and the run's cursor moved past them (AD-10).
  # data = { import_run_id:, last_appid: }, the cursor after the page.
  class TagsPageImported < RubyEventStore::Event
  end
end
