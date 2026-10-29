require "jwt"

module Accounts
  class ClerkClient
    include Dry::Monads[:result]

    JWKS_LIFETIME = 1.hour
    JWKS_REFETCH_COOLDOWN = 30.seconds
    LEEWAY = 5
    PROVIDERS = { "oauth_discord" => "discord", "oauth_google" => "google" }.freeze
    LOCAL_ORIGINS = %w[http://localhost:3000 http://127.0.0.1:3000 http://localhost:3036 http://127.0.0.1:3036].freeze

    class Error < StandardError; end

    class_attribute :adapter, default: nil

    @jwks_lock = Mutex.new
    @jwks = nil
    @jwks_fetched_at = nil
    @jwks_attempted_at = nil

    class << self
      def configured?
        adapter.present? || Rails.configuration.x.clerk.secret_key.present?
      end

      def authorized_parties
        origins = [ Rails.configuration.x.public_url ]
        origins += LOCAL_ORIGINS unless Rails.env.production?
        origins.compact
      end

      def reset_jwks!
        @jwks_lock.synchronize { @jwks = @jwks_fetched_at = @jwks_attempted_at = nil }
      end

      def jwk_for(kid, adapter)
        @jwks_lock.synchronize do
          fetched = false
          if @jwks.nil? || @jwks_fetched_at < JWKS_LIFETIME.ago
            fetch_jwks(adapter)
            fetched = true
          end
          fetch_jwks(adapter) if !@jwks.key?(kid) && !fetched && @jwks_attempted_at < JWKS_REFETCH_COOLDOWN.ago
          @jwks[kid]
        end
      end

      private

      def fetch_jwks(adapter)
        @jwks_attempted_at = Time.current
        @jwks = adapter.jwks.select { it.is_a?(Hash) && it["kid"].is_a?(String) }.index_by { it["kid"] }
        @jwks_fetched_at = Time.current
      end
    end

    def initialize(adapter: self.class.adapter || HttpAdapter.new)
      @adapter = adapter
    end

    def verify_session(token)
      kid = JWT.decode(token.to_s, nil, false).last["kid"]
      jwk = self.class.jwk_for(kid, @adapter) if kid.is_a?(String)
      return Failure(:invalid_session) unless jwk

      claims = JWT.decode(token, JWT::JWK.import(jwk).public_key, true, algorithms: %w[RS256], iss: issuer, verify_iss: true,
        verify_expiration: true, verify_not_before: true, required_claims: %w[exp], leeway: LEEWAY).first
      authorized_session?(claims) ? Success(claims) : Failure(:invalid_session)
    rescue JWT::DecodeError, JWT::JWKError, ArgumentError, TypeError
      Failure(:invalid_session)
    rescue Error => error
      unavailable(error)
    end

    def user(clerk_user_id)
      body = @adapter.user(clerk_user_id)
      return Failure(:clerk_unavailable) unless body.is_a?(Hash) && body["id"].is_a?(String)

      Success(build_user(body))
    rescue Error => error
      unavailable(error)
    end

    def delete_user(clerk_user_id)
      @adapter.delete_user(clerk_user_id)
      Success()
    rescue Error => error
      unavailable(error)
    end

    private

    def issuer
      "https://#{Rails.configuration.x.clerk.frontend_api}"
    end

    def authorized_session?(claims)
      claims["sub"].is_a?(String) && claims["sub"].present? && self.class.authorized_parties.include?(claims["azp"])
    end

    def unavailable(error)
      Rails.logger.warn("Clerk unavailable: #{error.message}")
      Failure(:clerk_unavailable)
    end

    def build_user(body)
      accounts = Array(body["external_accounts"]).filter_map { build_external_account(it) }
      ClerkUser.new(id: body["id"], external_accounts: accounts, primary_verified_email: primary_verified_email(body))
    end

    def build_external_account(account)
      return unless account.is_a?(Hash)

      provider = PROVIDERS[account["provider"]]
      uid = account["provider_user_id"]
      return unless provider && uid.is_a?(String) && uid.present?

      ClerkUser::ExternalAccount.new(provider:, uid:, email: account["email_address"].presence,
        verified: account.dig("verification", "status") == "verified")
    end

    def primary_verified_email(body)
      primary = Array(body["email_addresses"]).find { it.is_a?(Hash) && it["id"] == body["primary_email_address_id"] }
      primary["email_address"].presence if primary && primary.dig("verification", "status") == "verified"
    end
  end
end
