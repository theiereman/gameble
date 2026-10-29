require "test_helper"
require_relative "../support/clerk_fake"

class AccountsDeleteClerkUserJobTest < ActiveJob::TestCase
  include ClerkFake

  test "it deletes the Clerk user" do
    fake = ClerkFake.install(users: { "user_1" => ClerkFake.api_user("user_1") })

    Accounts::DeleteClerkUserJob.perform_now("user_1")

    assert_equal [ "user_1" ], fake.deleted
  end

  test "it retries when Clerk is unavailable" do
    ClerkFake.install(users: {}).unavailable = true

    assert_enqueued_with(job: Accounts::DeleteClerkUserJob, args: [ "user_1" ]) do
      Accounts::DeleteClerkUserJob.perform_now("user_1")
    end
  end

  test "it gives up after ten attempts" do
    ClerkFake.install(users: {}).unavailable = true
    job = Accounts::DeleteClerkUserJob.new("user_1")
    job.exception_executions = { "[Accounts::DeleteClerkUserJob::Unavailable]" => 9 }

    assert_raises(Accounts::DeleteClerkUserJob::Unavailable) { job.perform_now }
  end

  test "it retries without a secret key instead of dropping the erasure" do
    key = Rails.configuration.x.clerk.secret_key
    Rails.configuration.x.clerk.secret_key = nil

    assert_enqueued_with(job: Accounts::DeleteClerkUserJob, args: [ "user_1" ]) { Accounts::DeleteClerkUserJob.perform_now("user_1") }
  ensure
    Rails.configuration.x.clerk.secret_key = key
  end
end
