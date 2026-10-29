module Accounts
  class DeleteClerkUserJob < ActiveJob::Base
    queue_as :default

    class Unavailable < StandardError; end

    retry_on Unavailable, wait: :polynomially_longer, attempts: 10

    def perform(clerk_user_id)
      return unless ClerkClient.configured?

      raise Unavailable, "Clerk could not delete a user" if ClerkClient.new.delete_user(clerk_user_id).failure?
    end
  end
end
