module Game
  module Market
    # The seasons and genres the market's filters offer: those of the published seasons.
    module ListingFilterOptions
      Options = Data.define(:genres, :seasons)

      def self.call
        seasons = Catalog::Season.published
        genres = Catalog::CardSeason.where(season_id: seasons.select(:id)).where.not(main_theme: nil).distinct.order(:main_theme).pluck(:main_theme)
        Options.new(genres:, seasons: seasons.order(:number).pluck(:number))
      end
    end
  end
end
