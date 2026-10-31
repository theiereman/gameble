module Game
  module CustomSetByToken
    def self.call(token)
      return nil unless token.is_a?(String) && token.present?

      CustomSet.find_by(token:)
    end
  end
end
