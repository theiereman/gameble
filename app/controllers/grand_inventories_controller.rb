class GrandInventoriesController < ApplicationController
  include PublicRead
  include GrandInventoryGrid

  VIEWS = %w[cards pioneers sets].freeze

  SetRow = Data.define(:set, :progress)

  def show
    authorize :page, :show?
    @season = Catalog::PublishedSeason.call
    return if @season.nil?

    @inventory = Game::GrandInventory.new(seasons: inventory_scope(params), season: @season)
    @filters = inventory_filters(@inventory, params)
    @friends = Game::FriendsOf.call(current_player).to_set(&:id)
    load_inventory_grid
    respond_to do |format|
      format.html do
        @view = VIEWS.include?(params[:view]) ? params[:view] : VIEWS.first
        load_pace
        load_set_rows
        load_set_filter(@filters)
        @pioneer_boards = helpers.pioneer_boards(@inventory.scope, current_player)
        load_supporters(@latest&.player, *@pioneer_boards.flat_map { it.rows.map(&:player) })
      end
      format.turbo_stream { load_supporters }
    end
  end

  private
    def load_inventory_grid
      @query = grid_query(params)
      @states = inventory_states(params)
      @states_asked = grid_list(params, :state).any?
      @context = inventory_context(@inventory, params)
      @pagy, page = pagy(:offset, inventory_cards(@inventory, @filters, params), limit: GRID_SIZE, page: page_param)
      tiles = page.pluck(:id, :card_id)
      views = Catalog::CardViews.call(tiles.map(&:first), locale: I18n.locale)
      pioneers = @inventory.pioneers_of(tiles.map(&:last))
      @slots = tiles.filter_map { |id, card_id| [ views[id], pioneers[card_id] ] if views.key?(id) }
    end

    def load_supporters(*players)
      @supporters = Game::SupporterStatus.for_players(@slots.map { |_card, discovery| discovery&.player } + players)
    end

    def load_pace
      now = Time.current.utc
      @week_found = @inventory.found_since(now.beginning_of_week(:monday))
      @today_found = @inventory.found_since(now.beginning_of_day)
      @latest = @inventory.latest_discovery
    end

    def load_set_rows
      progresses = @inventory.set_progresses
      sets = Catalog::SetsById.call(progresses.map(&:set_id))
      rows = progresses.filter_map { SetRow.new(set: sets[it.set_id], progress: it) if sets.key?(it.set_id) }
      complete, open = rows.partition { it.progress.complete? }
      @complete_sets = complete.sort_by { [ -it.progress.completed_at.to_r, it.set.id ] }
      @closest_sets = open.sort_by { [ it.progress.missing, -it.progress.found.fdiv(it.progress.total), it.set.id ] }
    end
end
