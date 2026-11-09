class PublicProfilesController < ApplicationController
  include PublicRead
  include CollectionGridLoading
  include SetBoardLoading
  include SetAlbumLoading
  include ProfileLoading
  include FortunePeriod

  before_action :authorize_page
  before_action :load_owner

  def show
    @fortune = Game::FortuneStanding.call(@owner, period: fortune_period(params[:fortune]))
    return render(partial: "public_profiles/fortune", locals: { owner: @owner, fortune: @fortune }) if fortune_tab_request?

    load_profile(@owner)
    @owner_title = Game::ActiveProfileTitle.call(@owner)
    load_relation
  end

  def summary
    @owner_title = Game::ActiveProfileTitle.call(@owner)
    @fortune = Game::FortuneStanding.call(@owner, period: :week)
    @rarities = Game::HeldGames.by_rarity(@owner)
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
    def fortune_tab_request?
      turbo_frame_request_id == "profile-fortune"
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
    end
end
