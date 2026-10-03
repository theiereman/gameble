# Absolute links handed out to the world (CAP-9): a shared card's link, its
# og:url and its canonical link. Their base is the configured public one
# (config.x.public_url, from PUBLIC_URL), never the request's Host header,
# which a client can forge.
module PublicUrlsHelper
  # Raised in production when PUBLIC_URL is not set.
  class MissingPublicUrl < StandardError; end

  # The configured public base followed by `path`. Without a configured base,
  # the request's own base outside production (development, test), and an
  # error in production.
  def public_url_for(path)
    "#{public_base_url}#{path}"
  end

  private
    def public_base_url
      configured = Rails.configuration.x.public_url
      return configured if configured.present?
      raise MissingPublicUrl, "PUBLIC_URL is not set" if Rails.env.production?

      request.base_url
    end
end
