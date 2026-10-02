module Catalog
  # The dust levels on the back of a card (DESIGN.md, Dust), defined once
  # here. Keys only: labels live in the locale files. The database holds the
  # integer, checked BETWEEN 0 AND 4.
  #
  # A card-season's dust level is set when its season is published, from the
  # game's age on the publication date (`level_for`).
  module Dust
    LEVELS = { 0 => :none, 1 => :light, 2 => :marked, 3 => :thick, 4 => :buried }.freeze

    # The least age, in completed years, of each level above none.
    MIN_AGES = { 4 => 20, 3 => 10, 2 => 5, 1 => 1 }.freeze

    # The age in completed years between a release date and a date; a date
    # before the release counts as 0. A 29 February release has its
    # anniversary on 1 March in common years.
    def self.age(release_date, on:)
      age = on.year - release_date.year
      age -= 1 if (on.month * 100) + on.day < (release_date.month * 100) + release_date.day
      [ age, 0 ].max
    end

    # The dust level of a game released on `release_date`, published on `on`.
    def self.level_for(release_date, on:)
      age = age(release_date, on:)
      MIN_AGES.each { |level, min_age| return level if age >= min_age }
      0
    end
  end
end
