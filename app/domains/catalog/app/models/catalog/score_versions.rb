module Catalog
  # Whether a season's rows carry prestige scores from more than one formula
  # (SeasonRows::Row#prestige_score_version). Scores of two formulas are on
  # two scales, so the percentile cut would put every card of the lower one
  # in common. A row with no version counts as a version of its own; rows
  # that all have none are not mixed.
  #
  #   Catalog::ScoreVersions.mixed?(rows) # => true | false
  module ScoreVersions
    def self.mixed?(rows)
      rows.map(&:prestige_score_version).uniq.size > 1
    end
  end
end
