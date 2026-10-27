module Steam
  class SignInIdentity
    extend Dry::Monads[:result]

    PROVIDER = "steam".freeze
    # Over OpenID, Steam sends only the claimed id (the OmniAuth uid).
    CLAIMED_ID = %r{\Ahttps://steamcommunity\.com/openid/id/(\d{17})\z}

    def self.steam_id_from(auth)
      return Failure(:invalid_claimed_id) unless auth.respond_to?(:[]) && auth["provider"].to_s == PROVIDER

      match = CLAIMED_ID.match(auth["uid"].to_s)
      match ? Success(match[1]) : Failure(:invalid_claimed_id)
    end

    def self.failure_key(code)
      "errors.steam.#{code}"
    end
  end
end
