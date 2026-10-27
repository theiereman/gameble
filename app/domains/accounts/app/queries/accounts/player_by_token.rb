module Accounts
  module PlayerByToken
    def self.call(token)
      return nil unless token.is_a?(String) && token.present?

      Player.find_by(token: token)
    end
  end
end
