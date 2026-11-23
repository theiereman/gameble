class SlotPurchasesController < ApplicationController
  include GoalControlLoading

  KINDS = { "goals" => :goal, "custom-sets" => :custom_set, "decks" => :deck }.freeze

  throttle_player to: 10, only: :create, alert: "slot_purchases.create.throttled",
    path: -> { new_slot_purchase_path(capacity: params[:capacity].to_s, slot: params[:slot].to_s, **aim) }

  def new
    authorize :slot_purchase, :new?
    load_slot
    load_terms
    @refusal = flash[:alert] || standing_refusal
  end

  def create
    authorize :slot_purchase, :create?
    load_slot
    result = Game::BuySlot.new.call(player: current_player, kind: @kind, slot: @slot, settings_token: params[:settings_token].to_s, aim:)
    return bought if result.success?

    load_terms
    @refusal = refusal(result.failure)
    respond_to do |format|
      format.turbo_stream { render :create, status: :unprocessable_content }
      format.html { render :new, status: :unprocessable_content }
    end
  end

  private
    def load_slot
      @kind = KINDS.fetch(params[:capacity])
      @slot = params[:slot].to_i
      raise ActiveRecord::RecordNotFound unless (Game::Capacity::FREE.fetch(@kind) + 1..Game::Capacity::CEILING.fetch(@kind)).cover?(@slot)

      @aim = aim
      @set_name = aimed_set_name if @kind == :goal
    end

    def aim
      return {} unless params[:capacity] == "goals"

      params.key?(:custom_set) ? { custom_set: params[:custom_set].to_s } : { kind: params[:kind].to_s, key: params[:key].to_s }
    end

    def aimed_set_name
      name = if @aim.key?(:custom_set)
        Game::CustomSetStandings.call(current_player, tokens: [ @aim[:custom_set] ]).first&.then { helpers.custom_set_display_name(it) }
      else
        season = Catalog::PublishedSeason.call if Catalog::SetKind::ALL.include?(@aim[:kind])
        album = Catalog::SetAlbum.call(season:, kind: @aim[:kind], key: @aim[:key]) if season
        SetLabel.for(album.set) if album
      end
      name || raise(ActiveRecord::RecordNotFound)
    end

    def load_terms
      @settings = Game::Market::CurrentSettings.call || raise(ActiveRecord::RecordNotFound)
      @limit = Game::Capacity.limit(current_player, @kind)
      raise ActiveRecord::RecordNotFound if @slot > @limit + 1

      @available = Game::Market::Balance.call(current_player).available
      @price = @settings.slot_price(@kind, @slot) if @slot == @limit + 1
      @state = if @price.nil? then :closed
      elsif @available < @price then :short
      else :buyable
      end
    end

    def standing_refusal
      refusal(@limit >= Game::Capacity::CEILING.fetch(@kind) ? :slot_ceiling : :slot_already_bought) if @price.nil?
    end

    def refusal(code) = (Game::BuySlot.failure_message(code) unless code == :more_than_available)

    def bought
      case @kind
      when :goal then goal_bought
      when :custom_set then opened_after_purchase(library_path)
      when :deck then opened_after_purchase(new_deck_path)
      end
    end

    def opened_after_purchase(path)
      flash[:slot_bought] = @kind.to_s
      redirect_to path, status: :see_other
    end

    def goal_bought
      load_goal_control(@aim)
      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: turbo_stream.replace("set-album-goal", partial: "goals/control",
            locals: { aim: @goal_aim, goal: @goal, offer: @goal_slot, bought: true, orders: @goal_orders }, method: :morph)
        end
        format.html do
          flash[:notice] = helpers.goal_bought_sentence(@goal)
          redirect_to helpers.goal_album_path(@goal), status: :see_other
        end
      end
    end
end
