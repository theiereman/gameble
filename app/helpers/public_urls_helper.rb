# Absolute links handed out to the world (CAP-9): a card's share link, its
# og:url and its canonical link. Their base is the configured public one
# (config.x.public_url, from PUBLIC_URL, checked at boot by
# config/initializers/public_url.rb), never the request's Host header, which
# a client can forge.
module PublicUrlsHelper
  # Raised in production when no public base is configured. Production
  # refuses to boot without PUBLIC_URL, so this guards a configuration
  # changed after boot only.
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
