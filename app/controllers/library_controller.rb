# The collection: its entry, the search over every set and the viewer's sets
# in progress, or popular sets to discover for a visitor, under the top
# bar's unique cards; the grid of every game of the published season and
# every game the viewer holds, in any edition, with
# its filters, its search and the RAPPORT; and one set's album, the
# viewer's best edition of each of its games. A player's grid sets the
# cards they do not hold apart, faded and locked; a visitor, or a banned
# player, owns nothing and sees every card's plain face in the grid and
# every album slot missing, and no ownership data: no state filters, no
# RAPPORT, no unique cards in the top bar. Sets are addressed by
# kind and key, cards by slug; no id reaches the page. A GET writes
# nothing: a grid that showed new cards posts the latest gain it showed to
# CollectionSeenController. Open to any browser (PublicRead).
class LibraryController < ApplicationController
  include PublicRead
  include CollectionGridLoading
  include SetBoardLoading
  include SetAlbumLoading

  # GET /:locale/library: the entry, the viewer's sets, or popular ones for a visitor.
  def show
    authorize :page, :show?
    @season = Catalog::PublishedSeason.call
    return if @season.nil?

    load_unique_cards
    load_set_board(@season, owner: current_player)
    load_discover(@season) if current_player.nil?
  end

  # GET /:locale/library/cards: the grid of every game.
  def cards
    authorize :page, :show?
    @season = Catalog::PublishedSeason.call
    return if @season.nil?

    @grid = collection_grid(@season, params)
    load_summary
    load_grid(@grid)
    load_set_filter(@grid)
  end

  # GET /:locale/library/:kind/:key: one set's album.
  def set
    authorize :page, :show?
    @season = Catalog::PublishedSeason.call
    load_set_album(@season, owner: current_player, with_new: true)
    load_unique_cards
  end

  private
    # @grid_pagy and @slots: [ [ Catalog::CardView, Game::HeldGames::Edition | nil ], … ]
    # in grid order, nil for a game the viewer does not hold; @grid_context,
    # the filters and search each slot's link carries, so the card's
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
      @grid_context = grid_context(params, seen: (shown_watermark if @states.include?("new")))
      @grid_pagy, page = pagy(:offset, grid_cards(grid, @states), limit: GRID_SIZE, page: page_param, querify: pages_query)
      tiles = page.pluck(:id, :card_id)
      views = Catalog::CardViews.call(tiles.map(&:first), locale: I18n.locale)
      held = Game::HeldGames.editions(current_player, card_ids: tiles.map(&:last), season: @season)
      @slots = tiles.filter_map { |id, card_id| [ views[id], held[card_id] ] if views.key?(id) }
      @seen_up_to = held.values.select(&:new).map(&:gained_at).max
    end

    # A visitor's grid pages name no state: their grid ignores it.
    def pages_query
      ->(query) { query.delete("state") } if current_player.nil?
    end

    def load_set_filter(grid)
      @set_kinds = Catalog::SetKind::ALL & Catalog::SeasonSets.kinds(season: @season)
      return if @set_kinds.empty?

      @set_kind = @set_kinds.include?(params[:set_kind]) ? params[:set_kind] : @set_kinds.first
      @set_query = SetSearch.clean(params[:set_q].is_a?(String) ? params[:set_q] : "")
      found = SetSearch.in_kind(season: @season, kind: @set_kind, query: @set_query, locale: I18n.locale,
        except: grid.chosen_sets.map { [ it.kind, it.key ] })
      @set_options = grid.chosen_sets + found.sets
      @set_found = found.count
    end

    # The watermark this grid judges new cards against; for a player who
    # has seen none yet, a time before any gain, so every gain stays new.
    def shown_watermark
      Game::CollectionWatermark.call(current_player) || NOTHING_SEEN
    end

    # The games held per best rarity (@games_by_rarity), the games held
    # (@unique) out of the season's cards (@season_cards), and the copies
    # held per rarity tier (@tier_counts), every edition counted.
    def load_summary
      @games_by_rarity = Game::HeldGames.by_rarity(current_player)
      @unique = @games_by_rarity.values.sum
      @season_cards = Catalog::CardCount.call(@season)
      @tier_counts = Game::TierCounts.call(current_player)
    end

    def load_unique_cards
      @unique = Game::HeldGames.count(current_player)
      @season_cards = Catalog::CardCount.call(@season)
    end
end
