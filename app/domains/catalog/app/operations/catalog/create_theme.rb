module Catalog
  # An administrator makes a theme out of a Steam tag: the theme gets a name
  # in each language (the tag's English name by default, French typed by
  # hand, both chosen by the caller) and the tag is attached to it. The
  # theme's key is the tag's key, followed by a number when another theme has
  # it already.
  #
  # Publishes Catalog::ThemeCreated.
  #
  #   Catalog::CreateTheme.new.call(tag_key: "roguelite", name_en: "Roguelite", name_fr: "Roguelite")
  #   # => Success(theme) | Failure(:invalid_tag) | Failure(:invalid_theme_name)
  class CreateTheme < ApplicationOperation
    include ThemeEditing

    def call(tag_key:, name_en:, name_fr:)
      tag_keys = step validate_tag_keys([ tag_key ])
      names = step validate_names(name_en:, name_fr:)

      transaction do
        theme = Theme.create!(key: free_key(tag_keys.first), **names)
        step classify(tag_keys, theme)
        ThemeNames.reload
        step publish_change(ThemeCreated.new(data: { theme_id: theme.id, tag_key: }))
        theme
      end
    end

    private

    def free_key(tag_key)
      taken = Theme.where("key = :key OR key LIKE :numbered", key: tag_key, numbered: "#{Theme.sanitize_sql_like(tag_key)}\\_%").pluck(:key).to_set
      return tag_key unless taken.include?(tag_key)

      (2..).lazy.map { |number| "#{tag_key}_#{number}" }.find { |key| taken.exclude?(key) }
    end
  end
end
