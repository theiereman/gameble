module Catalog
  # The number of the draft season, or the number the next draft will take
  # when there is none: the season an import run begins on.
  module DraftSeasonNumber
    def self.call
      Season.draft.pick(:number) || Season.next_number
    end
  end
end
