module ClerkContentSecurityPolicy
  extend ActiveSupport::Concern

  BOT_PROTECTION = [ "https://challenges.cloudflare.com", "https://cdn.protect.clerk.com" ].freeze

  included do
    content_security_policy do |policy|
      api = Rails.configuration.x.clerk.frontend_api
      if api.present?
        policy.connect_src(*policy.directives["connect-src"], "https://#{api}", *BOT_PROTECTION)
        policy.script_src(*policy.directives["script-src"], *BOT_PROTECTION)
        policy.frame_src(:self, *BOT_PROTECTION)
      end
    end
  end
end
