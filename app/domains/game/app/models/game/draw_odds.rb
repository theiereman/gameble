module Game
  module DrawOdds
    TOTAL = 10_000

    REGULAR = { 1 => 7_600, 2 => 1_900, 3 => 430, 4 => 65, 5 => 5 }.freeze

    GUARANTEE = { 3 => 8_600, 4 => 1_300, 5 => 100 }.freeze

    BONUS = { 2 => 7_000, 3 => 2_400, 4 => 500, 5 => 100 }.freeze

    REWARD = { 2 => 7_000, 3 => 2_400, 4 => 588, 5 => 12 }.freeze

    EPIC_OR_BETTER = { 4 => 9_809, 5 => 191 }.freeze
  end
end
