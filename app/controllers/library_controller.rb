# The library (CAP-6, epic 4 R1, R2, R6, R7), reached from the attic's
# lectern: the published season's sets of one kind, as tomes on a shelf,
# fifty to a page, each with its name and how many of its cards the viewer
# owns; and one set opened beside the shelf, its slots in order, the owned
# cards face up with their copies, the missing ones naming their game. A
# visitor, or a banned player, owns nothing (CAP-18). Catalog answers the
# sets, their sizes and cards, Game the player's progress and copies; this
# layer pages, labels and joins them. Sets are addressed by kind and key; no
# set or card-season id reaches the page (AD-15).
class LibraryController < ApplicationController
  include Pagy::Method

  # The tabs, in their order; the first is the default.
  KINDS = %w[tome publisher best_of_year].freeze
  SHELF_SIZE = 50
  # No shelf goes this far; a larger page would overflow the OFFSET.
  MAX_PAGE = 100_000

  # A tome on the shelf: its key, name and the viewer's owned / total cards.
  Spine = Data.define(:key, :label, :owned, :total)

  # GET /:locale/library?kind=…&page=n. An unknown, blank or repeated kind
  # shows the tomes; a page past the last shows an empty shelf (any page
  # beyond MAX_PAGE is read as MAX_PAGE), and a page that is not a number
  # the first.
  def show
    authorize :page, :show?
    @kind = KINDS.include?(params[:kind]) ? params[:kind] : KINDS.first
    load_shelf(Catalog::PublishedSeason.call)
  end

  # GET /:locale/library/:kind/:key?page=n: one set opened, beside page n
  # of its kind's shelf (the first without it). The route admits only the
  # three kinds; a key the published season holds under no set of this
  # kind, or no published season, is not found.
  def set
    authorize :page, :show?
    season = Catalog::PublishedSeason.call
    raise ActiveRecord::RecordNotFound if season.nil?

    slots = Catalog::SetSlots.call(season_id: season.id, kind: params[:kind], key: params[:key])
    raise ActiveRecord::RecordNotFound if slots.nil?

    @kind = slots.set.kind
    @set = slots.set
    @shelf_page = page_param if params[:page].present?
    load_shelf(season)

    views = Catalog::CardViews.call(slots.card_season_ids, locale: I18n.locale)
    @slots = slots.card_season_ids.each_with_object({}) { |id, ordered| ordered[id] = views[id] if views.key?(id) }
    @quantities = Game::Quantities.call(current_player, @slots.keys)
  end

  private
    # The shelf of @kind in `season`: @pagy and @spines, both nil without a
    # season.
    def load_shelf(season)
      relation = Catalog::SeasonShelf.relation(kind: @kind, season:)
      return if relation.nil?

      @pagy, sets = pagy(:offset, relation, limit: SHELF_SIZE, page: page_param)
      sets = sets.to_a
      ids = sets.map(&:id)
      totals = Catalog::SetTotals.call(ids)
      owned = Game::SetProgress.call(current_player, ids)
      @spines = sets.map do |set|
        Spine.new(key: set.key, label: SetLabel.for(set), owned: owned.fetch(set.id, 0), total: totals.fetch(set.id, 0))
      end
    end

    def page_param
      params[:page].to_s.to_i.clamp(1, MAX_PAGE)
    end
end
