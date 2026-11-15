module Catalog
  module SeasonNumberKnown
    def self.call(number)
      Season.exists?(number:)
    end
  end
end
