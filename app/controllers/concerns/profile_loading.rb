module ProfileLoading
  extend ActiveSupport::Concern
  include SetBoardLoading
  include ChosenCards

  MOST_COMPLETE_SETS_SHOWN = 6

  private
    def load_profile(owner)
      @season = Catalog::PublishedSeason.call
      @card_total = Catalog::CardCount.call(@season)
      @summary = capped_at_card_total(Game::CollectionSummary.call(owner, season: @season))
      @achievements = Game::EarnedAchievements.call(owner)
      @showcase = chosen_cards(owner)
      load_season_sections(owner) if @season
    end

    def capped_at_card_total(summary)
      summary.with(distinct_cards: [ summary.distinct_cards, @card_total ].min)
    end

    def load_season_sections(owner)
      @rarities = Game::HeldGames.by_rarity(owner)
      @activity = Game::ProfileActivity.call(owner)
      standings = started_standings(owner)
      @started_set_count = standings.size
      @started_sets = most_complete_set_tiles(standings, owner)
      @goals = Game::GoalNeeds.on_game_sets(owner)
    end

    def started_standings(owner)
      Game::SetsInProgress.call(owner, season: @season).values
        .sort_by { |standing| [ standing.complete? ? 0 : 1, -standing.share, standing.set_id ] }
    end

    def most_complete_set_tiles(standings, owner)
      shown = standings.first(MOST_COMPLETE_SETS_SHOWN)
      set_tiles(set_rows(shown, Catalog::SetsById.call(shown.map(&:set_id))), owner:, season: @season)
    end
end
