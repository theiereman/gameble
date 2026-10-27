module Catalog
  # The published season: the highest-numbered published one, or nil (AD-5).
  module PublishedSeason
    def self.call
      Season.published.order(number: :desc).first
    end
  end
end
