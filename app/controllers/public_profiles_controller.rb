class PublicProfilesController < ApplicationController
  include PublicRead
  include CollectionGridLoading
  include SetBoardLoading
  include SetAlbumLoading
  include ChosenCards

  MOST_COMPLETE_SETS_SHOWN = 6

  before_action :authorize_page
  before_action :load_owner

  def show
    @season = Catalog::PublishedSeason.call
    @card_total = Catalog::CardCount.call(@season)
    @summary = capped_at_card_total(Game::CollectionSummary.call(@owner, season: @season))
    @achievements = Game::EarnedAchievements.call(@owner)
    @showcase = chosen_cards(@owner)
    load_stats_and_sets if @season
    load_relation
  end

  def set
    load_set_album(Catalog::PublishedSeason.call, owner: @owner, with_new: false)
  end

  def collection
    @season = Catalog::PublishedSeason.call
    return if @season.nil?

    @grid = collection_grid(@season, params)
    load_summary
    load_grid(@grid)
    load_set_filter(@grid)
  end

  private
    def capped_at_card_total(summary)
      summary.with(distinct_cards: [ summary.distinct_cards, @card_total ].min)
    end

    def grid_owner
      @owner
    end

    def grid_another?
      true
    end

    def authorize_page
      authorize :page, :show?
    end

    def load_owner
      @owner = Accounts::PlayerByToken.call(params[:token])
      return if Game::Visibility.visible?(current_player, @owner)

      render "public_profiles/unavailable", status: :not_found
    end

    def load_relation
      return unless Game::Visibility.visible?(current_player, @owner, staff_sees_all: false)

      @relation = Game::ProfileRelation.call(current_player, @owner)
      @open_trade_token = Game::OpenTradesByFriend.call(current_player)[@owner.id] if @relation == :friends
    end

    def load_stats_and_sets
      @rarities = Game::HeldGames.by_rarity(@owner)
      @activity = Game::ProfileActivity.call(@owner)
      standings = started_standings
      @started_set_count = standings.size
      @started_sets = most_complete_set_tiles(standings)
    end

    def started_standings
      Game::SetsInProgress.call(@owner, season: @season).values
        .sort_by { |standing| [ standing.complete? ? 0 : 1, -standing.share, standing.set_id ] }
    end

    def most_complete_set_tiles(standings)
      shown = standings.first(MOST_COMPLETE_SETS_SHOWN)
      set_tiles(set_rows(shown, Catalog::SetsById.call(shown.map(&:set_id))), owner: @owner, season: @season)
    end
end
