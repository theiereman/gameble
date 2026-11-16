require "faraday"

module Accounts
  class DiscordClient
    BASE_URL = "https://discord.com/api/v10".freeze
    REDACTED = "[FILTERED]".freeze
    NOT_A_MEMBER_CODES = [ 10_007, 10_013 ].freeze

    class Error < StandardError; end
    class RateLimited < Error; end

    class_attribute :adapter, default: [ Faraday.default_adapter ]

    def initialize(token: Rails.configuration.x.discord.bot_token, guild_id: Rails.configuration.x.discord.guild_id)
      @token = token.to_s
      @guild_id = guild_id.to_s
    end

    def configured?
      @token.present? && @guild_id.present?
    end

    def member?(discord_user_id)
      raise Error, "Discord is not configured" unless configured?

      connection.get("guilds/#{ERB::Util.url_encode(@guild_id)}/members/#{ERB::Util.url_encode(discord_user_id)}")
      true
    rescue Faraday::ResourceNotFound => error
      raise Error, "Discord does not know the server or the bot is not in it" unless NOT_A_MEMBER_CODES.include?(error_code(error))

      false
    rescue Faraday::TooManyRequestsError => error
      raise RateLimited.new(redact("#{error.class}: #{error.message}")), cause: nil
    rescue Faraday::Error => error
      raise Error.new(redact("#{error.class}: #{error.message}")), cause: nil
    end

    def inspect
      "#<#{self.class.name}>"
    end

    def redact(message)
      return message.to_s if @token.empty?

      [ @token, CGI.escape(@token), ERB::Util.url_encode(@token) ].uniq.reduce(message.to_s) do |text, secret|
        text.gsub(secret, REDACTED)
      end
    end

    private

    def error_code(error)
      JSON.parse(error.response_body.to_s)["code"]
    rescue JSON::ParserError
      nil
    end

    def connection
      @connection ||= Faraday.new(url: BASE_URL, headers: { "Authorization" => "Bot #{@token}" },
        request: { timeout: 10, open_timeout: 5 }) do |f|
        f.response :raise_error
        f.adapter(*adapter)
      end
    end
  end
end
