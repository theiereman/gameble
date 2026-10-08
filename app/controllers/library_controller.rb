# The collection (CAP-6; DESIGN.md and EXPERIENCE.md, Collection), reached
# from the hub's menu 02, its set progress rows and the phone's COLLECTION
# tab: on the side, the published season's sets of one kind as progress
# rows, under a "whole season" row, fifty to a page, and the RAPPORT of the
# viewer's copies; beside them, the grid of the scope picked (the whole
# season, or one set), sixty slots to a page. It opens on the owned cards,
# newest first on the whole season; a folded FILTRES zone narrows it by state,
# rarity, set and genre (OR within a group, AND across) and a search by
# title or publisher: the owned cards face up with their copies and, when
# gained since the player last saw them, "Nouveau" (AD-26); the missing ones
# naming their game. A visitor, or a banned player, owns nothing (CAP-18),
# so with no state chosen they see every slot, as does a player who owns
# nothing yet.
#
# Catalog answers the season, its sets, sizes and cards, Game the viewer's
# progress, copies and what is new; this layer pages, labels and joins them.
# Sets are addressed by kind and key, cards by slug; no id reaches the page
# (AD-15). The GET writes nothing (AD-11): a page that showed new cards
# posts the latest gain it showed to CollectionSeenController. A card's
# sets lead here, so, like the card's page, it is open to any browser
# (PublicRead).
#
# Parameters: `kind`, the kind of the sets listed (the tomes for an
# unknown, blank or repeated one; on a set's page, its own kind); `shelf`,
# the page of that list; `page`, the page of the grid; the grid's filters
# and search (CollectionGridLoading). A page past the last shows an empty
# list or grid; a page that is not a number, the first.
class LibraryController < ApplicationController
  include PublicRead
  include ShelfLoading
  include CollectionGridLoading

  # The page parameter of the list of sets; `page` pages the grid.
  SHELF_KEY = "shelf".freeze

  # GET /:locale/library: the whole season.
  def show
    authorize :page, :show?
    @season = Catalog::PublishedSeason.call
    return if @season.nil?

    @kind = KINDS.include?(params[:kind]) ? params[:kind] : KINDS.first
    load_collection(collection_grid(@season, params))
  end

  # GET /:locale/library/:kind/:key: one set. The route admits only the three
  # kinds; a key the published season holds under no set of this kind, or no
  # published season, is not found.
  def set
    authorize :page, :show?
    @season = Catalog::PublishedSeason.call
    raise ActiveRecord::RecordNotFound if @season.nil?

    grid = collection_grid(@season, params, kind: params[:kind], key: params[:key])
    raise ActiveRecord::RecordNotFound if grid.nil?

    @kind = grid.set.kind
    load_collection(grid)
  end

  private
    # The list of sets of @kind and its page, the grid's page with each
    # slot's card and the viewer's copies, and the figures of the top bar and
    # the RAPPORT.
    def load_collection(grid)
      @grid = grid
      load_shelf(Catalog::SeasonShelf.relation(kind: @kind, season: @season), owner: current_player, page_key: SHELF_KEY)
      load_summary
      load_grid(grid)
    end

    # @grid_pagy and @slots: [ [ Catalog::CardView, Game::CollectionSlots::Slot | nil ], … ]
    # in grid order, nil for a card the viewer does not hold; @grid_context,
    # the filters, search and set each slot's link carries, so the card's
    # detail walks this grid (CollectionGridLoading#grid_context), with the
    # player's watermark when the grid shows new cards by filter: showing
    # them moves it (collection_seen_controller.ts), and the detail judges
    # new against the one this grid was shown against. The
    # filters on: @query, @states (those asked, else @state_default) and
    # @states_asked. @seen_up_to: the latest gain among the new cards
    # shown, nil when none is.
    def load_grid(grid)
      @query = grid_query(params)
      asked = grid_states_asked(params)
      @states_asked = asked.any?
      @state_default = grid_default_state(@unique)
      @states = @states_asked ? asked : [ @state_default ]
      @grid_context = grid_context(params, grid.set, seen: (shown_watermark if @states.include?("new")))
      @grid_pagy, page = pagy(:offset, grid_cards(grid, @states), limit: GRID_SIZE, page: page_param)
      ids = page.pluck(:id)
      views = Catalog::CardViews.call(ids, locale: I18n.locale)
      held = Game::CollectionSlots.call(current_player, ids)
      @slots = ids.filter_map { |id| [ views[id], held[id] ] if views.key?(id) }
      @seen_up_to = held.values.select(&:new).map(&:gained_at).max
    end

    # The watermark this grid judges new cards against; for a player who
    # has seen none yet, a time before any gain, so every gain stays new.
    def shown_watermark
      Game::CollectionWatermark.call(current_player) || NOTHING_SEEN
    end

    # The distinct cards held in the season (@unique) out of its cards
    # (@season_cards), and the copies held per rarity tier (@tier_counts).
    def load_summary
      @unique = Game::CollectionSummary.distinct_cards(current_player, season: @season)
      @season_cards = Catalog::CardCount.call(@season)
      @tier_counts = Game::TierCounts.call(current_player)
    end
end
