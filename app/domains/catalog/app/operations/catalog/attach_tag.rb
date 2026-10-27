module Catalog
  # An administrator attaches a Steam tag to an existing theme, whatever it
  # was before (unclassified, another theme's, no theme). The draft's cards
  # follow only once the cards are rescored.
  #
  # Publishes Catalog::TagAttached.
  #
  #   Catalog::AttachTag.new.call(tag_key: "roguelite", theme:)
  #   # => Success(theme) | Failure(:invalid_tag)
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
