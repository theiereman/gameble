module Catalog
  module ThemeByToken
    def self.call(token)
      return nil unless token.is_a?(String) && token.present?

      Theme.find_by(token:)
    end
  end
end
