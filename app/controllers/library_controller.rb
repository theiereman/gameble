class LibraryController < ApplicationController
  include PublicRead
  include CollectionGridLoading
  include SetBoardLoading
  include SetAlbumLoading

  MORE_RESULTS_FRAME = "set-more-results-"

  def show
    authorize :page, :play?
    @season = Catalog::PublishedSeason.call
    return if @season.nil?

    load_set_search(@season, owner: current_player, offset: turbo_frame_request? ? tile_offset : 0)
    return render(:more_results) if turbo_frame_request_id.to_s.start_with?(MORE_RESULTS_FRAME)

    @custom_sets = Game::CustomSetStandings.call(current_player).select(&:custom?)
    load_unique_cards
  end

  def in_progress
    authorize :page, :play?
    return redirect_to library_path unless turbo_frame_request?

    section = params[:section] if BOARD_SECTIONS.include?(params[:section])
    load_set_tiles(Catalog::PublishedSeason.call, owner: current_player, section:, offset: tile_offset)
    render(:more_tiles) if section
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
    load_unique_cards
  end

  private
    def load_unique_cards
      @unique = Game::HeldGames.count(current_player)
      @season_cards = Catalog::CardCount.call(@season)
    end
end
