module Catalog
  # The wording of a roadmap milestone or story, in one language: one line of
  # visible text, at most LENGTH characters.
  module RoadmapWording
    LENGTH = 200

    # The wording squished to one line, or nil when it is no text or blank.
    def self.clean(value)
      return nil unless value.is_a?(String)

      value.dup.force_encoding(Encoding::UTF_8).scrub("").squish.presence
    end

    def self.valid?(wording)
      !wording.nil? && wording.length <= LENGTH
    end

    # The wording of a milestone or story in the current locale.
    module Localized
      def wording
        I18n.locale.to_s == "fr" ? wording_fr : wording_en
      end
    end
  end
end
