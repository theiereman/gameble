# A shelf of sets for the collection's grid (LibraryController, through
# load_shelf): the caller gives the ordered relation of the sets to shelve
# and the player whose progress it shows (never the viewer implicitly); the
# shelf is paged fifty to a page, each set labelled with its owner's owned /
# total. Sets are addressed by kind and key; no set id reaches the page.
module ShelfLoading
  extend ActiveSupport::Concern

  include Pagy::Method

  # The kinds of sets, in their tab order. A kind has a tab only when the
  # season holds sets of it (shelf_kinds).
  KINDS = %w[theme franchise studio hall_of_fame ufo].freeze
  SHELF_SIZE = 50
  # No shelf goes this far; a larger page would overflow the OFFSET.
  MAX_PAGE = 100_000

  # A set on the shelf: its kind and key, its name and the owner's
  # owned / total cards.
  Spine = Data.define(:kind, :key, :label, :owned, :total)

  private
    # The page of `relation` asked for: @pagy and @spines, both nil without a
    # relation (no published season). `owner`'s progress, nil for nothing
    # owned. The page is read from the parameter `page_key` (`page` unless
    # the caller pages something else with it), and its links write it.
    def load_shelf(relation, owner:, page_key: "page")
      return if relation.nil?

      @pagy, sets = pagy(:offset, relation, limit: SHELF_SIZE, page: page_param(page_key), page_key:)
      sets = sets.to_a
      ids = sets.map(&:id)
      totals = Catalog::SetTotals.call(ids)
      owned = Game::SetProgress.call(owner, ids)
      @spines = sets.map do |set|
        Spine.new(kind: set.kind, key: set.key, label: SetLabel.for(set), owned: owned.fetch(set.id, 0), total: totals.fetch(set.id, 0))
      end
    end

    # The KINDS `season` holds sets of, in tab order; none without a season.
    def shelf_kinds(season)
      KINDS & Catalog::SeasonShelf.kinds(season:)
    end

    # The page asked for in the parameter `key`: a number from 1 to
    # MAX_PAGE, 1 for anything that is not one.
    def page_param(key = "page")
      params[key].to_s.to_i.clamp(1, MAX_PAGE)
    end
end
