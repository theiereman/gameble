module Catalog
  # An administrator renames a theme, in both languages. Its key and its tags
  # stay; the cards of the theme show the new name at once, published seasons
  # included.
  #
  # Publishes Catalog::ThemeRenamed.
  #
  #   Catalog::RenameTheme.new.call(theme:, name_en: "Roguelike", name_fr: "Roguelike")
  #   # => Success(theme) | Failure(:invalid_theme_name)
  class RenameTheme < ApplicationOperation
    include ThemeEditing

    def call(theme:, name_en:, name_fr:)
      names = step validate_names(name_en:, name_fr:)

      transaction do
        theme.lock!
        theme.update!(names)
        ThemeNames.reload
        step publish_change(ThemeRenamed.new(data: { theme_id: theme.id }))
        theme
      end
    end
  end
end
