module Catalog
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
