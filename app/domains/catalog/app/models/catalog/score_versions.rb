module Catalog
  module ScoreVersions
    def self.mixed?(rows)
      rows.map(&:prestige_score_version).uniq.size > 1
    end
  end
end
