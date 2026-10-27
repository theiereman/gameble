module Catalog
  # The five rarity tiers (CAP-3), from the most common, defined once here.
  # Keys only: labels live in the locale files, the cut of a season into
  # tiers in its publication, the draw odds in Game. The database holds the
  # integer, checked BETWEEN 1 AND 5.
  module Rarity
    TIERS = { 1 => :common, 2 => :uncommon, 3 => :rare, 4 => :epic, 5 => :legendary }.freeze
  end
end
