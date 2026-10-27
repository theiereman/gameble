module Catalog
  module PublishedSeason
    def self.call
      Season.published.order(number: :desc).first
    end
  end
end
