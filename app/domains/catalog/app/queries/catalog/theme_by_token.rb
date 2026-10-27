module Catalog
  # Reads one theme by its token. Nil when absent; a token that is not a
  # String, or a blank one, costs no query.
  #
  #   Catalog::ThemeByToken.call("3fWq…") # => Catalog::Theme | nil
  module ThemeByToken
    def self.call(token)
      return nil unless token.is_a?(String) && token.present?

      Theme.find_by(token:)
    end
  end
end
