module Game
  module DuelByToken
    def self.call(token)
      return nil unless token.is_a?(String) && token.present?

      Duel.includes(:seats).find_by(token:)
    end
  end
end
