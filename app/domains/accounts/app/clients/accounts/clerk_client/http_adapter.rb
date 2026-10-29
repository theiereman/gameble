require "faraday"
require "faraday/retry"

module Accounts
  class ClerkClient
    class HttpAdapter
      BASE_URL = "https://api.clerk.com".freeze
      REDACTED = "[FILTERED]".freeze
      RETRY_STATUSES = [ 429, 500, 502, 503, 504 ].freeze

      class_attribute :connection_adapter, default: [ Faraday.default_adapter ]
      class_attribute :retry_interval, default: 1.0

      def initialize(secret_key: Rails.configuration.x.clerk.secret_key)
        @secret_key = secret_key.to_s
      end

      def jwks
        keys = get("/v1/jwks")&.fetch("keys", nil)
        raise Error, "the JWKS answer holds no key list" unless keys.is_a?(Array)

        keys
      end

      def user(clerk_user_id)
        get("/v1/users/#{ERB::Util.url_encode(clerk_user_id)}")
      end

      def delete_user(clerk_user_id)
        request { connection.delete("/v1/users/#{ERB::Util.url_encode(clerk_user_id)}") }
        true
      rescue Faraday::ResourceNotFound
        true
      end

      def inspect
        "#<#{self.class.name}>"
      end

      def redact(message)
        return message.to_s if @secret_key.empty?

        [ @secret_key, CGI.escape(@secret_key), ERB::Util.url_encode(@secret_key) ].uniq.reduce(message.to_s) do |text, secret|
          text.gsub(secret, REDACTED)
        end
      end

      private

      def get(path)
        request { connection.get(path).body }
      rescue Faraday::ResourceNotFound
        nil
      end

      def request
        raise Error, "CLERK_SECRET_KEY is not set" if @secret_key.empty?

        yield
      rescue Faraday::ResourceNotFound
        raise
      rescue Faraday::Error, JSON::ParserError => error
        raise Error.new(redact("#{error.class}: #{error.message}")), cause: nil
      end

      def connection
        @connection ||= Faraday.new(url: BASE_URL, headers: { "Authorization" => "Bearer #{@secret_key}" },
          request: { timeout: 10, open_timeout: 5 }) do |f|
          f.response :raise_error
          f.request :retry, max: 3, interval: retry_interval, backoff_factor: 2, max_interval: 30,
            retry_statuses: RETRY_STATUSES, methods: %i[get delete]
          f.response :json
          f.adapter(*connection_adapter)
        end
      end
    end
  end
end
