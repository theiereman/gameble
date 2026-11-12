module Game
  module Market
    class ChartPublication < ApplicationRecord
      self.table_name = "game_market_chart_publications"

      KINDS = %w[reactor rarity_prices edition_sales].freeze

      def published? = !published_at.nil? && (unpublished_at.nil? || published_at > unpublished_at)
    end
  end
end
