# A player's public profile (CAP-8, story 4.4, redrawn by story 10.3), at a
# link built on their token (AD-15): their collection, readable by anyone,
# signed out included (CAP-18), drawn with the collection's components in
# read-only mode. The list of sets opens on the ones they have started,
# beside the three kinds, each with the owner's progress (never the
# viewer's); a set opens beside the list with the owner's cards. The header counts
# their distinct cards and complete sets. Accounts answers the owner, Game
# whether their profile may be shown, Catalog the sets and cards, Game the
# owner's progress, copies and counts.
#
# An unknown token and a profile that may not be shown (a banned owner, or
# one whose visibility hides it from this viewer: Game::Visibility) render
# the same unavailable page with a 404, so a ban cannot be told from a
# missing player. These pages are read from shared links, so any browser
# and link-preview crawler gets them (PublicRead).
class PublicProfilesController < ApplicationController
  include PublicRead
  include ShelfLoading

  # The tab of the sets the owner has started, before the three kinds.
  STARTED = "started".freeze
  TABS = [ STARTED, *KINDS ].freeze

  before_action :authorize_page
  before_action :load_owner

  # GET /:locale/brothers/:token?kind=…&page=n. The Started tab without a
  # kind or with any kind it does not know.
  def show
    season = Catalog::PublishedSeason.call
    @kind = TABS.include?(params[:kind]) ? params[:kind] : STARTED
    load_shelf(shelf_relation(season), owner: @owner)
    @summary = Game::CollectionSummary.call(@owner, season:)
  end

  # GET /:locale/brothers/:token/library/:kind/:key?page=n&tab=started: one
  # of the owner's sets opened, beside page n of its kind's shelf, or of the
  # Started shelf with `tab=started`. As in the library, a key the published
  # season holds under no set of this kind, or no published season, is not
  # found.
  def set
    season = Catalog::PublishedSeason.call
    load_set(season, owner: @owner)
    @kind = params[:tab] == STARTED ? STARTED : @set.kind
    @shelf_page = page_param if params[:page].present?
    load_shelf(shelf_relation(season), owner: @owner)
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

    # The sets of the open tab in `season`: the owner's started sets of
    # every kind, or the sets of one kind; nil without a season.
    def shelf_relation(season)
      return Catalog::SeasonShelf.relation(kind: @kind, season:) unless @kind == STARTED

      sets = Catalog::SeasonShelf.every_kind(season:)
      sets && Game::StartedSets.relation(@owner, sets)
    end
end
