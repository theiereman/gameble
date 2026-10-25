# A set album's filters, read from its parameters, anything unknown
# ignored: `state[]` among STATES, judged by the album owner's holdings;
# `rarity[]`, of the face the album shows; `q`, found in the shown card's
# title, case and accents ignored. Answers the FILTRES zone
# (library/filters) as a Catalog::CollectionGrid does, without the set and
# genre groups.
class SetAlbumFilters < Data.define(:states, :states_asked, :chosen_rarities, :query)
  STATES = %w[owned all missing].freeze

  def self.from(params)
    asked = Game::CollectionStates.sanitize(list(params, :state)) & STATES
    new(states: asked.any? ? asked : [ Game::CollectionStates::DEFAULT ], states_asked: asked.any?,
      chosen_rarities: Catalog::Rarity::TIERS.values.map(&:to_s) & list(params, :rarity),
      query: params[:q].to_s.strip.first(Catalog::CollectionGrid::MAX_QUERY))
  end

  def self.list(params, key) = Array.wrap(params[key]).grep(String)
  private_class_method :list

  def initialize(query:, **)
    @needle = SetSearch.normalize(query)
    super
  end

  def chosen_sets = []
  def chosen_genres = []
  def genres = []

  def by_card? = chosen_rarities.any? || query.present?

  def shows_holding?(edition)
    states.include?(Game::CollectionStates::DEFAULT) || states.include?(edition ? "owned" : "missing")
  end

  def shows_card?(card)
    (chosen_rarities.empty? || chosen_rarities.include?(card.rarity)) && (@needle.empty? || SetSearch.normalize(card.title).include?(@needle))
  end
end
