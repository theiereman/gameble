# The collection: its entry, the viewer's sets in progress, to discover and
# searched, under the top bar's unique cards; the grid of every card of the
# published season, with its sets beside it, its filters and its search; and
# one set's album, the viewer's best edition of each of its games. A visitor,
# or a banned player, owns nothing and sees every slot missing. Sets are
# addressed by kind and key, cards by slug; no id reaches the page. A GET
# writes nothing: a grid that showed new cards posts the latest gain it
# showed to CollectionSeenController. Open to any browser (PublicRead).
class LibraryController < ApplicationController
  include PublicRead
  include ShelfLoading
  include CollectionGridLoading
  include SetBoardLoading
  include SetAlbumLoading

  # The page parameter of the list of sets; `page` pages the grid.
  SHELF_KEY = "shelf".freeze

  # GET /:locale/library: the entry, the viewer's sets.
  def show
    authorize :page, :show?
    @season = Catalog::PublishedSeason.call
    return if @season.nil?

    load_unique_cards
    load_set_board(@season, owner: current_player)
  end

  # GET /:locale/library/cards: the grid of the whole season.
  def cards
    authorize :page, :show?
    @season = Catalog::PublishedSeason.call
    return if @season.nil?

    @kinds = shelf_kinds(@season)
    @kind = @kinds.include?(params[:kind]) ? params[:kind] : (@kinds.first || KINDS.first)
    load_collection(collection_grid(@season, params))
  end

  # GET /:locale/library/:kind/:key: one set's album.
  def set
    authorize :page, :show?
    @season = Catalog::PublishedSeason.call
    load_set_album(@season, owner: current_player, with_new: true)
    load_unique_cards
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
    # filters on: @query, @states (those asked, else every slot) and
    # @states_asked. @seen_up_to: the latest gain among the new cards
    # shown, nil when none is.
    def load_grid(grid)
      @query = grid_query(params)
      asked = grid_states_asked(params)
      @states_asked = asked.any?
      @states = @states_asked ? asked : [ Game::CollectionStates::DEFAULT ]
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
      load_unique_cards
      @tier_counts = Game::TierCounts.call(current_player)
    end

    def load_unique_cards
      @unique = Game::CollectionSummary.distinct_cards(current_player, season: @season)
      @season_cards = Catalog::CardCount.call(@season)
    end
end
