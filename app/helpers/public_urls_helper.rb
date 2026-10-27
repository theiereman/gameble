module PublicUrlsHelper
  class MissingPublicUrl < StandardError; end

  def public_url_for(path)
    "#{public_base_url}#{path}"
  end

  private
    def public_base_url
      configured = Rails.configuration.x.public_url
      return configured if configured.present?
      raise MissingPublicUrl, "PUBLIC_URL is not set" if Rails.env.production?

      # base_url trusts the Host header, which a client can forge: development and test only.
      request.base_url
    end
end
