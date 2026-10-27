module Catalog
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
