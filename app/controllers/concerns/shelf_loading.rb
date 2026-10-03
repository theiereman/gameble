# A shelf of sets for a controller that shows one (CAP-6, CAP-8): the
# library of the signed-in player and a player's public profile. The caller
# gives the ordered relation of the sets to shelve and the player whose
# progress it shows (never the viewer implicitly); the shelf is paged fifty
# to a page, each set labelled with its owner's owned / total. Sets are
# addressed by kind and key; no set id reaches the page (AD-15).
module ShelfLoading
  extend ActiveSupport::Concern

  include Pagy::Method

  # The kinds of sets, in their tab order; the first is the library's default.
  KINDS = %w[tome publisher best_of_year].freeze
  SHELF_SIZE = 50
  # No shelf goes this far; a larger page would overflow the OFFSET.
  MAX_PAGE = 100_000

  # A tome on the shelf: its set's kind and key, its name and the owner's
  # owned / total cards.
  Spine = Data.define(:kind, :key, :label, :owned, :total)

  private
    # The page of `relation` asked for: @pagy and @spines, both nil without a
    # relation (no published season). `owner`'s progress, nil for nothing
    # owned.
    def load_shelf(relation, owner:)
      return if relation.nil?

      @pagy, sets = pagy(:offset, relation, limit: SHELF_SIZE, page: page_param)
      sets = sets.to_a
      ids = sets.map(&:id)
      totals = Catalog::SetTotals.call(ids)
      owned = Game::SetProgress.call(owner, ids)
      @spines = sets.map do |set|
        Spine.new(kind: set.kind, key: set.key, label: SetLabel.for(set), owned: owned.fetch(set.id, 0), total: totals.fetch(set.id, 0))
      end
    end

    # The shelf page asked for: a number from 1 to MAX_PAGE, 1 for anything
    # that is not one.
    def page_param
      params[:page].to_s.to_i.clamp(1, MAX_PAGE)
    end
end
