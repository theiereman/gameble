module Catalog
  # Whether the draft season's cards hold other themes than the tags'
  # classification gives them now, so the cards must be rescored. False
  # without a draft.
  #
  #   Catalog::DraftRescoreNeeded.call # => true | false
  module DraftRescoreNeeded
    def self.call
      Themes.classification.stale?(SeasonRows.call(Season.draft.select(:id)))
    end
  end
end
