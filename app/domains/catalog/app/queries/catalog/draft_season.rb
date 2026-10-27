module Catalog
  module DraftSeason
    def self.call
      Season.draft.take
    end
  end
end
