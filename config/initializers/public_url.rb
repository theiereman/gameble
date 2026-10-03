# The public base of the absolute links gameble hands out (CAP-9): a shared
# card's link, its og:url and its canonical link. It comes from PUBLIC_URL
# (AD-21: configuration from the environment only), never from the request's
# Host header, which a client can forge, and is checked here, at boot:
#
# - a malformed value refuses to boot in every environment;
# - in production a missing value refuses to boot too, except in the Docker
#   build's assets:precompile (SECRET_KEY_BASE_DUMMY set), which hands out
#   no link;
# - unset outside production, PublicUrlsHelper falls back to the request's
#   base.
#
# config.x.public_url holds the normalised base, "scheme://host[:port]", or
# nil when unset.
module PublicUrl
  # A missing or malformed PUBLIC_URL. Its message names PUBLIC_URL, never
  # the value, which could carry a secret.
  class Invalid < StandardError; end

  SCHEMES = %w[http https].freeze
  # A host name of letters, digits, dots and hyphens, or a bracketed IPv6
  # literal.
  HOST = /\A(?:[a-z0-9-]+(?:\.[a-z0-9-]+)*|\[[0-9a-f:.]+\])\z/
  PORTS = 1..65_535

  # The base of `value`, "scheme://host[:port]": an absolute http or https
  # URL with a host name or IPv6 literal, a port in 1..65535 if any, and no
  # user info, path (but "/"), query or fragment.
  # Its scheme and host are lowercased and the scheme's default port is
  # dropped. Nil for a blank value; PublicUrl::Invalid for any other.
  #
  #   PublicUrl.parse("https://Gameble.example/") # => "https://gameble.example"
  #   PublicUrl.parse("http://h:8080")            # => "http://h:8080"
  #   PublicUrl.parse("gameble.example")          # raises PublicUrl::Invalid
  def self.parse(value)
    return nil if value.blank?

    uri = URI.parse(value.strip)
    scheme = uri.scheme&.downcase
    host = uri.host&.downcase
    valid = SCHEMES.include?(scheme) && HOST.match?(host.to_s) && PORTS.cover?(uri.port) && uri.userinfo.nil? &&
      uri.path.in?([ "", "/" ]) && uri.query.nil? && uri.fragment.nil?
    raise invalid unless valid

    port = uri.port == uri.default_port ? "" : ":#{uri.port}"
    "#{scheme}://#{host}#{port}"
  rescue URI::Error
    raise invalid
  end

  # The base to configure from `value` (PUBLIC_URL) in `env`: PublicUrl.parse's,
  # and PublicUrl::Invalid for a missing value in production, unless
  # `dummy_build` (SECRET_KEY_BASE_DUMMY) is present.
  def self.configure(value, env: Rails.env, dummy_build: ENV["SECRET_KEY_BASE_DUMMY"])
    parse(value).tap do |base|
      if base.nil? && env.production? && dummy_build.blank?
        raise Invalid, "PUBLIC_URL is not set: production needs the public base of shared links (https://host)"
      end
    end
  end

  def self.invalid
    Invalid.new("PUBLIC_URL must be an absolute http or https URL with a host and no user info, path, query " \
      "or fragment (https://host or http://host:port)")
  end
  private_class_method :invalid
end

Rails.application.config.x.public_url = PublicUrl.configure(ENV["PUBLIC_URL"])
