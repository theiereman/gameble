class TradesController < ApplicationController
  rate_limit to: 20, within: 1.minute, only: %i[create counter accept decline cancel],
    by: -> { current_player&.id || request.remote_ip },
    with: -> { redirect_to trades_path, alert: t("trades.throttled"), status: :see_other }

  INSUFFICIENT = %i[requested_cards_unavailable insufficient_copies request_exceeds_holdings].freeze

  def index
    authorize :trade, :index?
    @trades = Game::TradesOf.call(current_player)
    @trade = @trades.first
    load_board(@trades, @trade)
  end

  def show
    authorize :trade, :show?
    @trade = find_trade!
    @trades = Game::TradesOf.call(current_player)
    load_board(@trades, @trade)
  end

  def new
    authorize :trade, :new?
    @friend = befriended(params[:friend]) or raise(ActiveRecord::RecordNotFound)
    if (refusal = privacy_refusal(@friend))
      refused(refusal, @friend)
      return redirect_to(trades_path)
    end

    @trades = Game::TradesOf.call(current_player)
    if (open = open_trade_with(@trades, @friend))
      show_refusal t("trades.one_at_a_time.text", name: helpers.friend_name(@friend)), title: t("trades.one_at_a_time.title")
      return redirect_to(trade_path(token: open.token))
    end

    @cards = card_views(@trades, nil)
    load_holdings(@friend)
  end

  def create
    authorize :trade, :create?
    friend = befriended(params[:friend])
    refusal = friend ? privacy_refusal(friend) : :not_friends
    if refusal
      refused(refusal, friend)
      return redirect_to(trades_path, status: :see_other)
    end

    result = with_sides(friend) do |offer, request|
      Game::ProposeTrade.new.call(player: current_player, recipient: friend, offer:, request:)
    end
    if result.success?
      flash[:trade_forget] = helpers.trade_draft_key(current_player, friend)
      toast t("trades.sent.title"), t("trades.sent.text", name: helpers.friend_name(friend))
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

    @trades = Game::TradesOf.call(current_player)
    @cards = card_views(@trades, @trade)
    load_holdings(@trade.friend)
  end

  def counter
    authorize :trade, :counter?
    trade = find_trade!

    result = with_sides(trade.friend) do |offer, request|
      Game::CounterTrade.new.call(player: current_player, trade_id: trade.id, offer:, request:)
    end
    if result.success?
      flash[:trade_forget] = helpers.trade_counter_key(current_player, trade)
      toast t("trades.sent.title"), t("trades.sent.text", name: helpers.friend_name(trade.friend))
      redirect_to trade_path(token: trade.token), status: :see_other
    else
      refused(result.failure, trade.friend)
      redirect_to counter_trade_path(token: trade.token), status: :see_other
    end
  end

  def accept
    authorize :trade, :accept?
    trade = find_trade!

    answer(trade, Game::AcceptTrade.new.call(player: current_player, trade_id: trade.id, revision: params[:revision])) do
      cards = Catalog::CardViews.call(trade.friend_side.map(&:card_season_id), locale: I18n.locale)
      gained = trade.friend_side.filter_map { |line| helpers.trade_line_title(line, cards) }
      toast t("trades.accepted.title"), t("trades.accepted.text", count: gained.size, cards: gained.to_sentence)
      flash[:trade_swap] = true
    end
  end

  def decline
    authorize :trade, :decline?
    trade = find_trade!

    answer(trade, Game::DeclineTrade.new.call(player: current_player, trade_id: trade.id, revision: params[:revision])) do
      toast t("trades.declined.title"), t("trades.declined.text", name: helpers.friend_name(trade.friend))
    end
  end

  def cancel
    authorize :trade, :cancel?
    trade = find_trade!

    answer(trade, Game::CancelTrade.new.call(player: current_player, trade_id: trade.id)) do
      toast t("trades.cancelled.title"), t("trades.cancelled.text")
    end
  end

  private
    def find_trade!
      Game::TradesOf.find(current_player, params[:token]) || raise(ActiveRecord::RecordNotFound)
    end

    def befriended(token)
      friend = Accounts::PlayerByToken.call(token)
      friend if befriended?(friend)
    end

    def befriended?(friend)
      friend.present? && !friend.removed? && Game::FriendshipBetween.call(current_player, friend)
    end

    def privacy_refusal(friend)
      if !Game::Visibility.open_to_friends?(current_player) then :own_profile_private
      elsif !Game::Visibility.open_to_friends?(friend) then :friend_profile_private
      end
    end

    def open_trade_with(trades, friend)
      (trades.yours + trades.theirs).find { |row| row.friend.id == friend.id }
    end

    def card_views(trades, trade)
      rows = [ trades.yours, trades.theirs, trades.recent, [ trade ] ].flatten.compact
      Catalog::CardViews.call(rows.flat_map(&:card_season_ids), locale: I18n.locale)
    end

    def load_board(trades, trade)
      @cards = card_views(trades, trade)
      case trade&.state
      when :yours then load_holdings(trade.friend)
      when :concluded
        received = trade.friend_side.map(&:card_season_id)
        @new_cards = Game::CollectionSlots.call(current_player, received).select { |_, slot| slot.new }.keys
      when :closed
        if befriended?(trade.friend)
          @trades_closed = privacy_refusal(trade.friend)
          @trade_again = @trades_closed.nil?
        end
      end
    end

    def load_holdings(friend)
      @own_cards = Game::HeldCopies.call(current_player)
      @friend_cards = Game::HeldCopies.call(friend)
      @picks = Catalog::CardViews.call(@own_cards.keys + @friend_cards.keys, locale: I18n.locale)
    end

    def with_sides(friend)
      own = Game::HeldCopies.call(current_player).keys
      theirs = Game::HeldCopies.call(friend).keys
      cards = Catalog::CardViews.call(own + theirs, locale: I18n.locale)
      offer = quantities(params[:give], own, cards)
      request = quantities(params[:take], theirs, cards)

      if offer.nil? then Dry::Monads::Failure(:invalid_offer)
      elsif request.nil? then Dry::Monads::Failure(:invalid_request)
      else yield offer, request
      end
    end

    def quantities(fields, held, cards)
      fields = fields.respond_to?(:to_unsafe_h) ? fields.to_unsafe_h : {}
      ids = held.filter_map { |id| (view = cards[id]) && [ helpers.trade_card_key(view), id ] }.to_h
      fields.each_with_object({}) do |(key, value), side|
        id = ids[key.to_s] or return
        value = value.to_s.strip
        side[id] = value unless value.empty? || value == "0"
      end
    end

    def answer(trade, result)
      if result.success?
        yield
      else
        refused(result.failure, trade.friend)
      end
      redirect_to trade_path(token: trade.token), status: :see_other
    end

    def toast(title, text)
      flash[:toast_title] = title
      flash[:notice] = text
    end

    def refused(code, friend = nil)
      message = Game::Operation.failure_message(code, name: (helpers.friend_name(friend) if friend))
      show_refusal message, title: (t("trades.insufficient") if INSUFFICIENT.include?(code))
    end

    def show_refusal(message, title: nil)
      flash[:trade_error] = message
      flash[:toast_title] = title if title
      flash[:alert] = message
    end
end
