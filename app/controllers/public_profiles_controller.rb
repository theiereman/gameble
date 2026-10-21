# A player's public profile, at a link built on their token, readable by
# anyone, signed out included: the owner's identity and key numbers, their
# showcase, stats, latest achievements and started sets, never the
# viewer's; and one of their sets' albums, read-only, with the owner's
# cards.
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
  include ChosenCards

  before_action :authorize_page
  before_action :load_owner

  # GET /:locale/brothers/:token
  def show
    @season = Catalog::PublishedSeason.call
    @summary = Game::CollectionSummary.call(@owner, season: @season)
    @card_total = Catalog::CardCount.call(@season)
    @achievements = Game::EarnedAchievements.call(@owner)
    @showcase = chosen_cards(@owner)
    load_stats_and_sets if @season
    load_relation
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

    def load_relation
      return unless Game::Visibility.visible?(current_player, @owner, staff_sees_all: false)

      @relation = Game::ProfileRelation.call(current_player, @owner)
      @open_trade_token = Game::OpenTradesByFriend.call(current_player)[@owner.id] if @relation == :friends
    end

    def load_stats_and_sets
      @rarities = Game::HeldGames.by_rarity(@owner)
      @activity = Game::ProfileActivity.call(@owner)
      @started_sets = started_set_rows
    end

    def started_set_rows
      standings = Game::SetsInProgress.call(@owner, season: @season).values
        .sort_by { |standing| [ standing.complete? ? 0 : 1, -standing.share, standing.set_id ] }
      set_rows(standings, Catalog::SetsById.call(standings.map(&:set_id)))
    end
end
