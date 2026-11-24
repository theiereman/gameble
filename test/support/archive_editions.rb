# Another edition of a fixture card's rarity, in a season of its own, so a test can buy one edition and read the others.
module ArchiveEditions
  def another_edition!(card, rarity)
    @another_editions = @another_editions.to_i + 1
    source = catalog_cards(card).dup.tap { it.update!(source_key: "src:9#{@another_editions}", slug: "another-#{@another_editions}") }
    season = Catalog::Season.find_by(number: 20) || Catalog::Season.create!(number: 20)
    Catalog::CardSeason.create!(card: source, season:, prestige_score: 0.5, rating: 80.0, rarity:, number: 20 + @another_editions)
  end
end
