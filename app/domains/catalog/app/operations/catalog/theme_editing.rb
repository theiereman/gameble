module Catalog
  module ThemeEditing
    private

    def validate_names(name_en:, name_fr:)
      names = { name_en: ThemeNaming.clean(name_en), name_fr: ThemeNaming.clean(name_fr) }
      names.values.all? { ThemeNaming.valid?(it) } ? Success(names) : Failure(:invalid_theme_name)
    end

    def validate_tag_keys(tag_keys)
      return Failure(:invalid_tag) unless tag_keys.is_a?(Array) && tag_keys.any? && tag_keys.all? { it.is_a?(String) && TagKey::FORMAT.match?(it) }

      Success(tag_keys.uniq)
    end

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
