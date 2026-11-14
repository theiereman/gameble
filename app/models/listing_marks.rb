class ListingMarks
  Mark = Data.define(:copies, :goals) do
    def owned? = copies.positive?

    def wanted? = !owned? && goals.any?

    def goal_numbers = wanted? ? goals.map(&:position) : []
  end

  UNMARKED = Mark.new(copies: 0, goals: []).freeze

  def self.for(player, rows, goal_marks)
    return NONE if player.nil?

    card_ids = rows.map { it.card.card_id }.uniq
    season = Catalog::PublishedSeason.call
    editions = season ? Game::HeldGames.editions(player, card_ids:, season:) : {}
    new(card_ids.to_h { [ it, Mark.new(copies: editions[it]&.copies || 0, goals: goal_marks.goals_for(it)) ] })
  end

  def initialize(by_card) = @by_card = by_card

  NONE = new({}).freeze

  def any? = @by_card.any?

  def for(card) = @by_card.fetch(card.card_id, UNMARKED)
end
