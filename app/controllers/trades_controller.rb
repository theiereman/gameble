class TradesController < ApplicationController
  include GoalsReachedTracking
  include TradeProposals
  include GoalMarksLoading

  helper_method :goal_marks

  throttle_player to: 20, only: %i[create counter accept decline cancel], path: -> { trades_path }, alert: "trades.throttled"
  rate_limit to: 120, within: 1.minute, only: :faces, name: "faces",
    by: -> { current_player&.id || request.remote_ip },
    with: -> { head :too_many_requests }

  def index
    authorize :trade, :index?
    load_list
    @trade = @trades.first
    load_board(@trade)
  end

  def show
    authorize :trade, :show?
    @trade = find_trade!
    load_list
    load_board(@trade)
  end

  def new
    authorize :trade, :new?
    return choose_friend unless params.key?(:friend)

    @friend = befriended(params[:friend])
    if (refusal = @friend ? helpers.trades_refusal(@friend) : :not_friends)
      refused(refusal, @friend)
      return redirect_to(trades_path)
    end

    load_list
    @cards = card_views(nil)
    load_holdings(@friend)
    @prefill = board_prefill(@friend)
  end

  def faces
    authorize :trade, :faces?
    pairs = requested_face_keys.filter_map { helpers.trade_card_key_parts(it) }
    views = Catalog::CardViews.call(Catalog::PublishedCardSeasonIds.call(pairs).values, locale: I18n.locale)
    render json: { faces: helpers.trade_card_faces(views.values) }
  end

  def create
    authorize :trade, :create?
    friend = befriended(params[:friend])
    refusal = friend ? helpers.trades_refusal(friend) : :not_friends
    if refusal
      refused(refusal, friend)
      return redirect_to(trades_path, status: :see_other)
    end

    sides = sent_sides(friend)
    result = sides.bind { Game::ProposeTrade.new.call(player: current_player, recipient: friend, **it) }
    if result.success?
      flash[:trade_forget] = helpers.trade_draft_key(current_player, friend)
      toast_sent(friend, sides.value![:offer])
      redirect_to trade_path(token: result.value!.token), status: :see_other
    else
      refused(result.failure, friend)
      redirect_to new_trade_path(friend: friend.token), status: :see_other
    end
  end

  def edit
    authorize :trade, :counter?
    @trade = find_trade!
    unless @trade.state == :yours
      flash.keep
      return redirect_to(trade_path(token: @trade.token))
    end

    load_list
    @cards = card_views(@trade)
    load_holdings(@trade.friend)
  end

  def counter
    authorize :trade, :counter?
    trade = find_trade!

    sides = sent_sides(trade.friend)
    result = sides.bind { Game::CounterTrade.new.call(player: current_player, trade_id: trade.id, revision: params[:revision], **it) }
    if result.success?
      flash[:trade_forget] = helpers.trade_counter_key(current_player, trade)
      toast_sent(trade.friend, sides.value![:offer])
      redirect_to trade_path(token: trade.token), status: :see_other
    else
      refused(result.failure, trade.friend)
      redirect_to counter_refused_path(trade, result.failure), status: :see_other
    end
  end

  def accept
    authorize :trade, :accept?
    trade = find_trade!

    result, reached = tracking_goals_reached(current_player) do
      Game::AcceptTrade.new.call(player: current_player, trade_id: trade.id, revision: params[:revision])
    end
    redirect_after(trade, result) do
      toast_goals_reached(reached)
      cards = Catalog::CardViews.call(trade.friend_side.map(&:card_season_id), locale: I18n.locale)
      gained = trade.friend_side.filter_map { |line| helpers.trade_line_title(line, cards) }
      toast t("trades.accepted.title"), t("trades.accepted.text", count: gained.size, cards: gained.to_sentence)
      flash[:trade_swap] = true
    end
  end

  def decline
    authorize :trade, :decline?
    trade = find_trade!

    redirect_after(trade, Game::DeclineTrade.new.call(player: current_player, trade_id: trade.id, revision: params[:revision])) do
      toast t("trades.declined.title"), t("trades.declined.text", name: helpers.friend_name(trade.friend))
    end
  end

  def cancel
    authorize :trade, :cancel?
    trade = find_trade!

    redirect_after(trade, Game::CancelTrade.new.call(player: current_player, trade_id: trade.id)) do
      text = trade.own_side.empty? ? t("trades.cancelled.open_text", name: helpers.friend_name(trade.friend)) : t("trades.cancelled.text")
      toast t("trades.cancelled.title"), text
    end
  end

  private
    def requested_face_keys
      keys = params[:keys]
      keys.is_a?(Array) ? keys.grep(String).first(TradesHelper::FACES_PER_REQUEST) : []
    end

    def choose_friend
      load_list
      @cards = card_views(nil)
      @friends = Game::FriendsPresence.call(current_player)
      render :choose
    end

    def find_trade!
      Game::TradesOf.find(current_player, params[:token]) || raise(ActiveRecord::RecordNotFound)
    end

    def load_list
      @trades = Game::TradesOf.call(current_player)
      @suggestions = Game::TradeSuggestions.call(current_player)
    end

    def card_views(trade)
      rows = [ @trades.yours, @trades.theirs, @trades.recent, [ trade ] ].flatten.compact
      Catalog::CardViews.call(rows.flat_map(&:card_season_ids) + @suggestions.card_season_ids, locale: I18n.locale)
    end

    def board_prefill(friend)
      return unless params.key?(:take) || params.key?(:give)

      keys = { take: prefill_keys(params[:take]), give: prefill_keys(params[:give]) }
      ids = Catalog::PublishedCardSeasonIds.call(keys.values.flatten.filter_map { helpers.trade_card_key_parts(it) })
      sides = keys.transform_values { |side| side.filter_map { (parts = helpers.trade_card_key_parts(it)) && ids[parts] } }
      TradeSuggestionsHelper::Prefill.new(friend:,
        take: Game::TradeSuggestions.still_spared(sides[:take], holder: friend, other: current_player,
          minimum_copies: Game::TradeSuggestions::DUPLICATE_COPIES),
        give: Game::TradeSuggestions.still_spared(sides[:give], holder: current_player, other: friend))
    end

    def prefill_keys(keys)
      keys.is_a?(Array) ? keys.grep(String).uniq.first(Game::TradeItem::MAX_CARDS_PER_SIDE) : []
    end

    def load_board(trade)
      @cards = card_views(trade)
      case trade&.state
      when :yours then load_holdings(trade.friend)
      when :concluded
        received = trade.friend_side.map(&:card_season_id)
        @new_cards = Game::CollectionSlots.call(current_player, received).select { |_, slot| slot.new }.keys
      when :closed
        if befriended?(trade.friend)
          @trades_closed = helpers.trades_refusal(trade.friend)
          @trade_again = @trades_closed.nil?
        end
      end
    end

    def load_holdings(friend)
      @own_cards = Game::HeldCopies.call(current_player)
      @friend_cards = Game::HeldCopies.call(friend)
      @picks = Catalog::CardViews.call(@own_cards.keys + @friend_cards.keys, locale: I18n.locale)
    end

    def counter_refused_path(trade, code)
      code == :trade_changed ? trade_path(token: trade.token) : counter_trade_path(token: trade.token)
    end

    def redirect_after(trade, result)
      if result.success?
        yield
      else
        refused(result.failure, trade.friend)
      end
      redirect_to trade_path(token: trade.token), status: :see_other
    end

    def toast_sent(friend, offer)
      name = helpers.friend_name(friend)
      toast t("trades.sent.title"), offer.empty? ? t("trades.sent.open_text", name:) : t("trades.sent.text", name:)
    end
end
