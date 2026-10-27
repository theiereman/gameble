require "openid/store/interface"
require "openid/store/nonce"

module Steam
  class OpenIdStore < OpenID::Store::Interface
    NONCE_SKEW = 5.minutes
    NONCE_MARGIN = 1.minute

    def initialize(cache: Rails.cache)
      @cache = cache
    end

    # The sign-in request carries no association handle, so Steam signs privately and each response is verified against Steam.
    def stateless?
      true
    end

    def store_association(_server_url, _association)
    end

    def get_association(_server_url, _handle = nil)
      nil
    end

    def remove_association(_server_url, _handle)
      false
    end

    def use_nonce(server_url, timestamp, salt)
      return false if (timestamp.to_i - Time.now.to_i).abs > NONCE_SKEW.to_i

      key = "steam/openid/nonce/#{Digest::SHA256.hexdigest([ server_url, timestamp, salt ].join("\n"))}"
      expires_in = timestamp.to_i + NONCE_SKEW.to_i + NONCE_MARGIN.to_i - Time.now.to_i
      @cache.write(key, true, unless_exist: true, expires_in: expires_in) ? true : false
    end

    def cleanup_nonces
      0
    end

    def cleanup_associations
      0
    end
  end
end
