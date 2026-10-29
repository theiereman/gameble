module Accounts
  class SignIn < ApplicationOperation
    def call(steam_id:, persona_name: nil)
      step SignInThroughIdentity.new.call(provider: "steam", uid: steam_id, persona_name:)
    end
  end
end
