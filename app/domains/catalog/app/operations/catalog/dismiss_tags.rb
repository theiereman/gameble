module Catalog
  # An administrator marks Steam tags as no theme, one or many at once. A
  # dismissed tag stops blocking the publication; it can be attached to a
  # theme later.
  #
  # Publishes Catalog::TagsDismissed.
  #
  #   Catalog::DismissTags.new.call(tag_keys: %w[indie action])
  #   # => Success(tag_keys) | Failure(:invalid_tag)
  class DismissTags < ApplicationOperation
    include ThemeEditing

    def call(tag_keys:)
      tag_keys = step validate_tag_keys(tag_keys)

      transaction do
        step classify(tag_keys, nil)
        step publish_change(TagsDismissed.new(data: { tag_keys: }))
        tag_keys
      end
    end
  end
end
