# A player's public profile, at a link built on their token, readable by
# anyone, signed out included: the summary, then their sets as the
# collection opens on them (SetBoardLoading), with the owner's progress,
# never the viewer's; and one of their sets' albums, read-only, with the
# owner's cards.
#
# An unknown token and a profile that may not be shown to this viewer
# (Game::Visibility: a banned owner, or one whose visibility hides it, for
# anyone but staff, who read every profile but a deleted one's) render the
# same unavailable page with a 404, so a ban cannot be told from a missing
# player. Read from shared links, so open to any browser and link-preview
# crawler (PublicRead).
class PublicProfilesController < ApplicationController
  include PublicRead
  include SetBoardLoading
  include SetAlbumLoading

  before_action :authorize_page
  before_action :load_owner

  # GET /:locale/brothers/:token?q=…: the summary and the owner's sets, the
  # set searched for with `q`.
  def show
    @season = Catalog::PublishedSeason.call
    load_set_board(@season, owner: @owner) if @season
    @summary = Game::CollectionSummary.call(@owner, season: @season)
  end

  # GET /:locale/brothers/:token/library/:kind/:key: the album of one of the
  # owner's sets.
  def set
    load_set_album(Catalog::PublishedSeason.call, owner: @owner, with_new: false)
  end

  private
    def authorize_page
      authorize :page, :show?
    end

    # The owner of the profile, or the unavailable page (which halts the
    # action) for an unknown token or a profile that may not be shown.
    def load_owner
      @owner = Accounts::PlayerByToken.call(params[:token])
      return if Game::Visibility.visible?(current_player, @owner)

      render "public_profiles/unavailable", status: :not_found
    end
end
