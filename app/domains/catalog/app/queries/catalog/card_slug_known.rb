module Catalog
  module CardSlugKnown
    def self.call(slug) = slug.is_a?(String) && Card.exists?(slug:)
  end
end
