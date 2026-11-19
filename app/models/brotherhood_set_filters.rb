class BrotherhoodSetFilters < SetAlbumFilters
  STATES = %w[found all missing].freeze
  MINE = "mine".freeze

  def self.offered(signed_in:) = signed_in ? [ *STATES, MINE ] : STATES

  def self.from(params, signed_in:)
    asked = list(params, :state) & offered(signed_in:)
    build(params, asked.size > 1 ? asked - [ Game::CollectionStates::DEFAULT ] : asked)
  end

  def shows_discovery?(found:, mine:)
    states.any? do |state|
      state == Game::CollectionStates::DEFAULT || (state == "found" && found) || (state == "missing" && !found) || (state == MINE && mine)
    end
  end
end
