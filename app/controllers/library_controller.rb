# The library (CAP-6, epic 4 R1, R6, R7), reached from the attic's lectern:
# the published season's sets of one kind, as tomes on a shelf, fifty to a
# page, each with its name and how many of its cards the viewer owns. A
# visitor, or a banned player, sees every set at 0 (CAP-18). Catalog answers
# the sets and their sizes, Game the player's progress; this layer pages,
# labels and joins them. No set id reaches the page (AD-15).
class LibraryController < ApplicationController
  include Pagy::Method

  # The tabs, in their order; the first is the default.
  KINDS = %w[tome publisher best_of_year].freeze
  SHELF_SIZE = 50
  # No shelf goes this far; a larger page would overflow the OFFSET.
  MAX_PAGE = 100_000

  # A tome on the shelf: its name and the viewer's owned / total cards.
  Spine = Data.define(:label, :owned, :total)

  # GET /:locale/library?kind=…&page=n. An unknown, blank or repeated kind
  # shows the tomes; a page past the last shows an empty shelf (any page
  # beyond MAX_PAGE is read as MAX_PAGE), and a page that is not a number
  # the first.
  def show
    authorize :page, :show?
    @kind = KINDS.include?(params[:kind]) ? params[:kind] : KINDS.first

    relation = Catalog::SeasonShelf.relation(kind: @kind)
    return if relation.nil?

    page = params[:page].to_s.to_i.clamp(1, MAX_PAGE)
    @pagy, sets = pagy(:offset, relation, limit: SHELF_SIZE, page:)
    sets = sets.to_a
    ids = sets.map(&:id)
    totals = Catalog::SetTotals.call(ids)
    owned = Game::SetProgress.call(current_player, ids)
    @spines = sets.map { |set| Spine.new(label: SetLabel.for(set), owned: owned.fetch(set.id, 0), total: totals.fetch(set.id, 0)) }
  end
end
