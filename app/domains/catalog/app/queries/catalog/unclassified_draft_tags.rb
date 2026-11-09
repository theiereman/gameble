module Catalog
  module UnclassifiedDraftTags
    def self.count
      classification = Themes.classification
      DraftTagUsage.call.keys.count { |tag_key| classification.theme_by_tag[tag_key].nil? && !classification.dismissed.include?(tag_key) }
    end
  end
end
