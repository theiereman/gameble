# The hop that signs the Hotwire Native apps in: the app opens the sign-in in
# the system browser, where Steam and Clerk's OAuth work, and the browser hands
# a short-lived ticket back to the app through its URL scheme. The app proves
# it started the hop by sending back the state it chose.
module NativeSignIn
  STATE = /[A-Za-z0-9_-]{32,128}/
  PATH = %r{\A/(?:#{I18n.available_locales.join("|")})/native/sign-in/#{STATE.source}\z}
  CALLBACK = "gameble://sign-in".freeze
  LIFETIME = 2.minutes
  PURPOSE = :native_sign_in

  class << self
    def path?(path)
      path.is_a?(String) && PATH.match?(path)
    end

    def callback_url(player, state:)
      "#{CALLBACK}?#{{ ticket: ticket(player, state:) }.to_query}"
    end

    def ticket(player, state:)
      verifier.generate({ "player" => player.token, "state" => state }, expires_in: LIFETIME, purpose: PURPOSE)
    end

    def player_for(ticket, state:)
      return nil unless ticket.is_a?(String) && state.is_a?(String) && state.match?(/\A#{STATE.source}\z/)

      data = verifier.verified(ticket, purpose: PURPOSE)
      return nil unless data.is_a?(Hash) && data["state"].is_a?(String) && ActiveSupport::SecurityUtils.secure_compare(data["state"], state)

      Accounts::PlayerByToken.call(data["player"])
    end

    private

    def verifier
      Rails.application.message_verifier(PURPOSE)
    end
  end
end
