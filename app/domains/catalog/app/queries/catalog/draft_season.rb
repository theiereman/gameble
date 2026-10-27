module Catalog
  # The draft season, or nil (AD-5).
  module DraftSeason
    def self.call
      Season.draft.take
    end
  end
end
