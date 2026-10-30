module Accounts
  class ForgetPushDevice < ApplicationOperation
    def call(token:)
      token = step require_token(token)

      transaction do
        PushDevice.where(token:).delete_all
        token
      end
    end

    private

    def require_token(token)
      token.is_a?(String) && token.present? ? Success(token) : Failure(:invalid_push_device)
    end
  end
end
