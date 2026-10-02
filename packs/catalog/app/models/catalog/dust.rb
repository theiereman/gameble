module Catalog
  # The dust levels on the back of a card (DESIGN.md, Dust), defined once
  # here. Keys only: labels live in the locale files, the age thresholds in
  # the season's publication. The database holds the integer, checked
  # BETWEEN 0 AND 4.
  module Dust
    LEVELS = { 0 => :none, 1 => :light, 2 => :marked, 3 => :thick, 4 => :buried }.freeze
  end
end
