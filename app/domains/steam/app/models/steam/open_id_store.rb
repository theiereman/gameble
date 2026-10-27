require "openid/store/interface"
require "openid/store/nonce"

module Steam
  # The OpenID store of the Steam sign-in, on Rails.cache (AD-12) so replay
  # protection holds across processes and hosts.
  #
  # Stateless: associations are not kept. The sign-in request carries no
  # association handle, so Steam signs with a private association and
  # ruby-openid verifies each response with check_authentication against
  # Steam (config/initializers/omniauth.rb disables association requests
  # for this store).
  #
  # Nonces: a response nonce is accepted once within the skew window; its key
  # is written with unless_exist, so a second use of the same nonce fails.
  class OpenIdStore < OpenID::Store::Interface
    NONCE_SKEW = 5.minutes
    NONCE_MARGIN = 1.minute

    def initialize(cache: Rails.cache)
      @cache = cache
    end

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
      # The key outlives the last moment the nonce is accepted (timestamp +
      # skew), with a margin, so no replay slips in at the boundary.
      expires_in = timestamp.to_i + NONCE_SKEW.to_i + NONCE_MARGIN.to_i - Time.now.to_i
      @cache.write(key, true, unless_exist: true, expires_in: expires_in) ? true : false
    end

    # Expired nonces leave the cache by themselves.
    def cleanup_nonces
      0
    end

    def cleanup_associations
      0
    end
  end
end
