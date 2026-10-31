module CustomSetPicking
  extend ActiveSupport::Concern

  RESULTS = 24

  private
    def picked_slugs
      Array(params[:games]).grep(String).uniq.first(Game::CustomSet::GAMES.max + 1)
    end

    def picked_card_ids(slugs)
      ids = Catalog::PublishedCardIds.by_slug(slugs)
      slugs.map { ids[it] }
    end

    def load_picker(slugs)
      @name = params[:name].is_a?(String) ? params[:name] : ""
      @query = params[:q].is_a?(String) ? params[:q].strip.first(Catalog::CollectionGrid::MAX_QUERY) : ""
      picked_ids = picked_card_ids(slugs).compact
      @picked = picker_cards(Catalog::LatestPublishedCardSeasons.call(picked_ids).values_at(*picked_ids).compact)
      @found = @query.present? ? picker_cards(found_card_season_ids(picked_ids)) : []
    end

    def found_card_season_ids(picked_ids)
      season = Catalog::PublishedSeason.call
      return [] if season.nil?

      Catalog::CollectionGrid.call(season:, query: @query, locale: I18n.locale).card_seasons
        .where.not(card_id: picked_ids).limit(RESULTS).pluck(:id)
    end

    def picker_cards(card_season_ids)
      views = Catalog::CardViews.call(card_season_ids, locale: I18n.locale)
      card_season_ids.filter_map { views[it] }
    end
end
