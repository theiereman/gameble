# A shelf of sets for a controller that shows one (CAP-6, CAP-8): the
# collection's list of sets (LibraryController, through load_shelf) and a
# player's public profile (PublicProfilesController, through load_shelf and
# load_set). The caller gives the ordered relation of the sets to shelve and
# the player whose progress it shows (never the viewer implicitly); the
# shelf is paged fifty to a page, each set labelled with its owner's owned /
# total. On the public profile one set can be opened beside it, its slots
# with that owner's copies (load_set). Sets are addressed by kind and key;
# no set or card-season id reaches the page (AD-15).
module ShelfLoading
  extend ActiveSupport::Concern

  include Pagy::Method

  # The kinds of sets, in their tab order: today's, then the retired ones a
  # season published before themes holds. A kind has a tab only when the
  # season holds sets of it (shelf_kinds).
  KINDS = %w[theme franchise studio hall_of_fame ufo tome publisher best_of_year].freeze
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

    # The set of `season`, the published one, asked for by `params[:kind]`
    # and `params[:key]`: @set, @slots ({ card_season_id => Catalog::CardView }
    # in slot order) and @quantities, `owner`'s copies of them (none for a
    # nil owner). No published season, or a key the season holds under no
    # set of this kind, is not found.
    def load_set(season, owner:)
      raise ActiveRecord::RecordNotFound if season.nil?

      slots = Catalog::SetSlots.call(season_id: season.id, kind: params[:kind], key: params[:key])
      raise ActiveRecord::RecordNotFound if slots.nil?

      @set = slots.set
      views = Catalog::CardViews.call(slots.card_season_ids, locale: I18n.locale)
      @slots = slots.card_season_ids.each_with_object({}) { |id, ordered| ordered[id] = views[id] if views.key?(id) }
      @quantities = Game::Quantities.call(owner, @slots.keys)
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
