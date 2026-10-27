# Every job is enqueued only once the transaction around it commits, and
# not at all when it rolls back: a job never reads uncommitted
# state. Set on ActiveJob::Base, so the jobs of the packs (which inherit it
# directly, not ApplicationJob), Turbo's broadcast jobs and the mailers'
# delivery jobs all follow it. Rails 8.1 has no global setting for it.
ActiveSupport.on_load(:active_job) do
  self.enqueue_after_transaction_commit = true
end
