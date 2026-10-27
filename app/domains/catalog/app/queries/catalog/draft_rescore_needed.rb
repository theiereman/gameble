module Catalog
  module DraftRescoreNeeded
    def self.call
      Themes.classification.stale?(SeasonRows.call(Season.draft.select(:id)))
    end
  end
end
