module Catalog
  module DraftTagUsage
    def self.call
      sql = <<~SQL.squish
        SELECT top_tag, COUNT(*) FROM catalog_card_seasons
        JOIN catalog_cards ON catalog_cards.id = catalog_card_seasons.card_id,
        LATERAL unnest(catalog_cards.tags[1:#{Themes::TOP_TAGS.to_i}]) AS top_tag
        WHERE catalog_card_seasons.season_id = (SELECT id FROM catalog_seasons WHERE status = 'draft' LIMIT 1)
        GROUP BY top_tag
      SQL
      Season.connection.select_rows(sql).to_h { |tag_key, count| [ tag_key, count.to_i ] }
        .sort_by { |tag_key, count| [ -count, tag_key ] }.to_h
    end
  end
end
