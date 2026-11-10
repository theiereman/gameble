module Game
  module Market
    # The settings version with this token, or nil.
    module FindSettings
      def self.call(token) = token.present? ? Settings.find_by(token: token.to_s) : nil
    end
  end
end
