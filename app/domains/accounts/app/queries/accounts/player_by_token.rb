module Accounts
  # Reads one player by their public token (AD-15), for the public profile
  # (CAP-8). Nil when absent; a token that is not a String, or a blank one,
  # costs no query.
  #
  #   Accounts::PlayerByToken.call("3fWq…") # => Accounts::Player | nil
  module PlayerByToken
    def self.call(token)
      return nil unless token.is_a?(String) && token.present?

      Player.find_by(token: token)
    end
  end
end
