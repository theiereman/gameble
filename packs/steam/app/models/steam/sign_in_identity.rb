module Steam
  # Turns the OmniAuth auth hash of a verified Steam OpenID response into a
  # Steam id (AD-4, AD-14). Over OpenID, Steam sends only the claimed id (the
  # OmniAuth uid); a Steam id is accepted only from its exact form.
  #
  #   Steam::SignInIdentity.steam_id_from(auth)
  #   # => Success("76561197960287930") | Failure(:invalid_claimed_id)
  #
  # A failure code's message is the locale key errors.steam.<code>.
  class SignInIdentity
    extend Dry::Monads[:result]

    PROVIDER = "steam".freeze
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
