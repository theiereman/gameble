module Steam
  # Published when the review summaries of a page of apps are stored and the
  # run's cursor moved past them (AD-10). data = { import_run_id:, last_appid: },
  # the cursor after the page.
  class ReviewsPageImported < RubyEventStore::Event
  end
end
