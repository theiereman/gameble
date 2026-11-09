class LibraryController < ApplicationController
  include PublicRead
  include CollectionGridLoading
  include SetBoardLoading
  include GoalSuggestionLoading
  include SetAlbumLoading
  include GoalControlLoading

  helper_method :goal_marks

  ALL_CARDS_FAN = 3

  def show
    authorize :page, :play?
    @season = Catalog::PublishedSeason.call
    return if @season.nil?

    own_sets = browsable_own_sets(current_player)
    @custom_set_tiles, library_tiles = own_set_tiles(own_sets, owner: current_player, season: @season).partition { it.own_set.custom? }
    @steam_library_tile = library_tiles.first
    @sets_total = Catalog::SeasonSets.every_kind(season: @season).count + own_sets.size
    load_goals
    load_unique_cards
    load_latest_cards
  end

  def in_progress
    authorize :page, :play?
    return redirect_to library_path unless turbo_frame_request?

    @goals = Game::GoalNeeds.targets(current_player)
    load_in_progress_preview(Catalog::PublishedSeason.call, owner: current_player, goals: @goals)
  end

  def sets
    authorize :page, :play?
    @season = Catalog::PublishedSeason.call
    return if @season.nil?

    load_set_browser(@season, owner: current_player, goals: goal_marks, page: page_param)
    respond_to do |format|
      format.html { load_unique_cards }
      format.turbo_stream
    end
  end

  def cards
    authorize :page, :show?
    @season = Catalog::PublishedSeason.call
    return if @season.nil?

    @grid = collection_grid(@season, params)
    load_grid(@grid)
    respond_to do |format|
      format.html do
        load_summary if current_player
        load_set_filter(@grid)
      end
      format.turbo_stream
    end
  end

  def set
    authorize :page, :play?
    @season = Catalog::PublishedSeason.call
    load_set_album(@season, owner: current_player, with_new: true)
    load_goal_control({ kind: @set.kind, key: @set.key }, targets: goal_marks.targets)
    load_unique_cards
  end

  private
    def load_goals
      @goals = goal_marks.needs
      @goal_suggestions = @goals.empty? ? goal_suggestions(current_player, season: @season) : []
    end

    def load_unique_cards
      @unique = Game::HeldGames.count(current_player)
      @season_cards = Catalog::CardCount.call(@season)
    end

    def load_latest_cards
      ids = Game::LatestGains.call(current_player, season: @season, limit: ALL_CARDS_FAN)
      @latest_cards = Catalog::CardViews.call(ids, locale: I18n.locale).values_at(*ids).compact
    end
end
