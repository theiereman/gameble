# ClerkFake: `include ClerkFake`, then `ClerkFake.install(users: { "user_1" => ClerkFake.api_user("user_1", accounts: [ { provider: "discord", uid: "d-1" } ]) })` and `ClerkFake.session_token(user_id: "user_1")`; undone after each test.
require "jwt"

module ClerkFake
  KID = "test-key".freeze
  AZP = "http://localhost:3000".freeze

  # The stand-in for Accounts::ClerkClient::HttpAdapter: answers from `users` and records what it was asked.
  class Adapter
    attr_reader :users, :deleted, :jwks_calls
    attr_accessor :unavailable

    def initialize(users)
      @users = users.stringify_keys
      @deleted = []
      @jwks_calls = 0
      @unavailable = false
    end

    def jwks
      fail_if_unavailable
      @jwks_calls += 1
      [ JWT::JWK.new(ClerkFake.signing_key.public_key, kid: KID).export.stringify_keys ]
    end

    def user(clerk_user_id)
      fail_if_unavailable
      users[clerk_user_id]
    end

    def delete_user(clerk_user_id)
      fail_if_unavailable
      deleted << clerk_user_id
      users.delete(clerk_user_id)
      true
    end

    private

    def fail_if_unavailable
      raise Accounts::ClerkClient::Error, "Clerk is down" if unavailable
    end
  end

  def self.included(test_case)
    test_case.teardown { ClerkFake.uninstall }
  end

  def self.signing_key
    @signing_key ||= OpenSSL::PKey::RSA.generate(2048)
  end

  # Swaps the client's adapter for a fake over `users` (Clerk user ids to API-shaped hashes); returns the fake.
  def self.install(users: {})
    uninstall
    @adapter_was = Accounts::ClerkClient.adapter
    @installed = true
    Accounts::ClerkClient.adapter = Adapter.new(users)
    Accounts::ClerkClient.reset_jwks!
    Accounts::ClerkClient.adapter
  end

  def self.uninstall
    return unless @installed

    @installed = false
    Accounts::ClerkClient.adapter = @adapter_was
    Accounts::ClerkClient.reset_jwks!
  end

  # A token the fake JWKS accepts: RS256, the instance issuer, 60 seconds of life, `azp` as the page origin.
  def self.session_token(user_id:, azp: AZP, expires_in: 60, issued_at: Time.now, issuer: "https://#{Rails.configuration.x.clerk.frontend_api}", kid: KID)
    claims = { sub: user_id, sid: "sess_test", iss: issuer, azp:, nbf: issued_at.to_i, iat: issued_at.to_i, exp: issued_at.to_i + expires_in }
    JWT.encode(claims, signing_key, "RS256", { kid: })
  end

  # A Clerk Backend API user: `accounts` are { provider: "discord" | "google" | other, uid:, email:, verified: } hashes
  # (provider without its "oauth_" prefix); `email` is the primary address of the user.
  def self.api_user(id, accounts: [], email: nil, email_verified: true)
    status = ->(verified) { { "status" => verified ? "verified" : "unverified" } }
    {
      "id" => id,
      "primary_email_address_id" => (email ? "idn_#{id}" : nil),
      "email_addresses" => (email ? [ { "id" => "idn_#{id}", "email_address" => email, "verification" => status.(email_verified) } ] : []),
      "external_accounts" => accounts.map do |account|
        { "id" => "eac_#{account.fetch(:uid)}", "provider" => "oauth_#{account.fetch(:provider)}", "provider_user_id" => account.fetch(:uid),
          "email_address" => account[:email], "verification" => status.(account.fetch(:verified, true)) }
      end
    }
  end
end
