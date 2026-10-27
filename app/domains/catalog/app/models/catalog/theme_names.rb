module Catalog
  # The stored names of the themes, by key, read once per request or job (a
  # screen names many cards) and read again after a theme changes.
  #
  #   Catalog::ThemeNames.of("horror", :fr) # => "Horreur" | nil
  class ThemeNames < ActiveSupport::CurrentAttributes
    attribute :by_key

    def self.of(key, locale = I18n.locale)
      names = (self.by_key ||= Theme.pluck(:key, :name_en, :name_fr).to_h { |theme_key, en, fr| [ theme_key, { "en" => en, "fr" => fr } ] })
      names.dig(key.to_s, locale.to_s == "fr" ? "fr" : "en")
    end

    def self.reload
      self.by_key = nil
    end
  end
end
