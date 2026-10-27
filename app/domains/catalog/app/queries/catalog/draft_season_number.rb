module Catalog
  module DraftSeasonNumber
    def self.call
      Season.draft.pick(:number) || Season.next_number
    end
  end
end
