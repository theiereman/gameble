module Catalog
  # What the theme operations share: the names and the tag keys an
  # administrator gives, checked and cleaned, and the write of a tag's
  # classification.
  module ThemeEditing
    private

    # Success({ name_en:, name_fr: }) squished, or Failure(:invalid_theme_name).
    def validate_names(name_en:, name_fr:)
      names = { name_en: ThemeNaming.clean(name_en), name_fr: ThemeNaming.clean(name_fr) }
      names.values.all? { ThemeNaming.valid?(it) } ? Success(names) : Failure(:invalid_theme_name)
    end

    # Success(tag_keys) without duplicates, or Failure(:invalid_tag) when
    # there is none or one is not a tag key.
    def validate_tag_keys(tag_keys)
      return Failure(:invalid_tag) unless tag_keys.is_a?(Array) && tag_keys.any? && tag_keys.all? { it.is_a?(String) && TagKey::FORMAT.match?(it) }

      Success(tag_keys.uniq)
    end

    # Classifies each tag key in one statement: attached to `theme`, or, with
    # none, no theme.
    def classify(tag_keys, theme)
      TagClassification.upsert_all(
        tag_keys.map { |tag_key| { tag_key:, theme_id: theme&.id, not_a_theme: theme.nil? } },
        unique_by: :tag_key
      )
      Success()
    end

    def publish_change(event)
      publish(event, stream_name: Theme.stream_name)
    end
  end
end
