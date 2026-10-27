# Steam sign-in: OmniAuth with omniauth-openid against Steam's
# OpenID 2.0 endpoint. Every sign-in setting lives here.
#
#   POST /auth/steam           request phase: POST only, CSRF-checked by
#                              omniauth-rails_csrf_protection
#   GET  /auth/steam/callback  verified response -> SessionsController#create
#   GET  /auth/failure         any failure       -> SessionsController#failure
require "openid"
require "openid/consumer"
require "openid/fetchers"
require "openid/store/nonce"

# ruby-openid verifies TLS certificates only when given a CA file.
OpenID.fetcher.ca_file = OpenSSL::X509::DEFAULT_CERT_FILE

# A response nonce older or newer than this is refused.
OpenID::Nonce.skew = 5.minutes.to_i

# A stateless store (Steam::OpenIdStore) keeps no association, so the request
# must not open one: Steam would sign with a shared key that it then refuses
# to verify through check_authentication. Without an association, Steam signs
# with a private one and check_authentication verifies the response.
module StatelessOpenIdAssociations
  def get_association
    return nil if @store.respond_to?(:stateless?) && @store.stateless?

    super
  end
end
OpenID::Consumer::AssociationManager.prepend(StatelessOpenIdAssociations)

OmniAuth.config.logger = Rails.logger
OmniAuth.config.allowed_request_methods = %i[post]
# Marks the session that started a sign-in, after the CSRF check passed;
# SessionsController#create refuses a callback without it (login CSRF).
OmniAuth.config.before_request_phase = ->(env) { env["rack.session"]["steam_sign_in_started"] = true }
# Failures redirect to /auth/failure in every environment, development too.
OmniAuth.config.on_failure = ->(env) { OmniAuth::FailureEndpoint.new(env).redirect_to_failure }

Rails.application.config.middleware.use OmniAuth::Builder do
  provider :open_id,
    name: "steam",
    identifier: "https://steamcommunity.com/openid",
    # Steam sends no profile data over OpenID; ask for none.
    required: [],
    optional: [],
    # The store is built per request so the reloadable Steam pack is not
    # autoloaded at boot.
    setup: ->(env) { env["omniauth.strategy"].options[:store] = Steam::OpenIdStore.new }
end
