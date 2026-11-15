require_relative "game_sets"
require_relative "holdings"

# Builds what a deck takes: editions a player holds, pulled once and ranked by the duel stats, and second editions of
# their games in a later season.
module Decks
  include GameSets
  include Holdings

  # `count` editions of a new published season, held by `player` and ranked; their card-season ids.
  def ranked_cards(player, count, quantity: 1, titles: nil)
    _season, ids = published_cards(count)
    titles&.each_with_index { |title, index| Catalog::CardText.where(card_id: card_of(ids[index])).update_all(title:) }
    hold_all(player, ids, quantity:)
    rank(ids)
    ids
  end

  # Another edition of each card-season's game in a new published season; its card-season ids.
  def second_editions(card_season_ids)
    season = Catalog::Season.create!(status: :published, number: Catalog::Season.next_number, published_at: Time.current)
    rows = Catalog::CardSeason.where(id: card_season_ids).order(:id).each_with_index.map do |first, index|
      { card_id: first.card_id, season_id: season.id, prestige_score: first.prestige_score, rating: first.rating,
        review_count: first.review_count, rarity: first.rarity, number: index + 1 }
    end
    Catalog::CardSeason.insert_all!(rows, returning: :id).rows.flatten
  end

  # Pulls each card-season once and computes the duel stats again.
  def rank(card_season_ids, player: accounts_players(:administrator))
    card_season_ids.each do |card_season_id|
      Game::FirstDiscovery.create!(card_season_id:, player_id: player.id, discovered_at: 1.day.ago) unless Game::FirstDiscovery.exists?(card_season_id:)
    end
    Game::ComputeDuelStats.new.call(reason: "first").value!
  end

  def card_of(card_season_id) = Catalog::CardSeason.where(id: card_season_id).pick(:card_id)

  def ref_of(card_season_id)
    slug, number = Catalog::CardSeason.joins(:card, :season).where(id: card_season_id).pick("catalog_cards.slug", "catalog_seasons.number")
    "#{slug}:#{number}"
  end

  def reserved_of(player, card_season_id) = Game::Holding.find_by!(player_id: player.id, card_season_id:).reserved
end
