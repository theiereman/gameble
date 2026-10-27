module Catalog
  class AttachTag < ApplicationOperation
    include ThemeEditing

    def call(tag_key:, theme:)
      tag_keys = step validate_tag_keys([ tag_key ])

      transaction do
        step classify(tag_keys, theme)
        step publish_change(TagAttached.new(data: { theme_id: theme.id, tag_key: }))
        theme
      end
    end
  end
end
