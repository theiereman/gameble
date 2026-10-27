module Catalog
  module RoadmapWording
    LENGTH = 200

    def self.clean(value)
      return nil unless value.is_a?(String)

      value.dup.force_encoding(Encoding::UTF_8).scrub("").squish.presence
    end

    def self.valid?(wording)
      !wording.nil? && wording.length <= LENGTH
    end

    module Localized
      def wording
        I18n.locale.to_s == "fr" ? wording_fr : wording_en
      end
    end
  end
end
