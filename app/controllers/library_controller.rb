class LibraryController < ApplicationController
  include PublicRead
  include CollectionGridLoading
  include SetBoardLoading
  include GoalTileLoading
  include SetAlbumLoading
  include GoalControlLoading

  helper_method :goal_marks

  MORE_RESULTS_FRAME = "set-more-results-"

  def show
    authorize :page, :play?
    @season = Catalog::PublishedSeason.call
    return if @season.nil?

    own_sets = Game::CustomSetStandings.call(current_player).select { it.custom? || it.ever_synced? }
    load_set_search(@season, owner: current_player, own_sets:, offset: turbo_frame_request? ? tile_offset : 0)
    return more_results if turbo_frame_request_id.to_s.start_with?(MORE_RESULTS_FRAME)

    @custom_set_tiles, library_tiles = own_set_tiles(own_sets, owner: current_player, season: @season).partition { it.own_set.custom? }
    @steam_library_tile = library_tiles.first
    load_goals
    load_unique_cards
  end

  def in_progress
    authorize :page, :play?
    return redirect_to library_path unless turbo_frame_request?

    @section = params[:section] if BOARD_SECTIONS.include?(params[:section])
    @goals = Game::GoalNeeds.targets(current_player)
    load_set_tiles(Catalog::PublishedSeason.call, owner: current_player, section: @section, offset: tile_offset, goals: @goals)
    render(:more_tiles) if @section
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
    def more_results
      @goals = Game::GoalNeeds.targets(current_player)
      render :more_results
    end

    def load_goals
      @goals = goal_marks.needs
      return @goal_tiles = @goal_suggestions = [] if turbo_frame_request?

      @goal_tiles = goal_tiles(@goals)
      @goal_suggestions = @goals.empty? ? goal_suggestions(current_player, season: @season) : []
    end

    def load_unique_cards
      @unique = Game::HeldGames.count(current_player)
      @season_cards = Catalog::CardCount.call(@season)
    end
end
