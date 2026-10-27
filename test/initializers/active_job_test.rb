require "test_helper"

# Jobs leave only once their transaction commits
# (config/initializers/active_job.rb): every job class, the packs' own
# (inheriting ActiveJob::Base) and the frameworks' included.
class ActiveJobInitializerTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  class SampleJob < ActiveJob::Base
    def perform = nil
  end

  test "every job class enqueues after commit" do
    [ ActiveJob::Base, ApplicationJob, SampleJob, Game::HealBanksJob, Game::BackfillPlayerStatesJob,
      ActionMailer::MailDeliveryJob, Turbo::Streams::BroadcastJob ].each do |job|
      assert job.enqueue_after_transaction_commit, "#{job} enqueues inside the transaction"
    end
  end

  test "a job enqueued in a transaction leaves only once it commits" do
    ApplicationRecord.transaction do
      SampleJob.perform_later
      assert_no_enqueued_jobs
    end

    assert_enqueued_jobs 1, only: SampleJob
  end

  test "a job enqueued in a transaction that rolls back never leaves" do
    ApplicationRecord.transaction do
      SampleJob.perform_later
      raise ActiveRecord::Rollback
    end

    assert_no_enqueued_jobs
  end

  test "outside a transaction, a job leaves at once" do
    SampleJob.perform_later

    assert_enqueued_jobs 1, only: SampleJob
  end
end
