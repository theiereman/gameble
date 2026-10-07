# The trades screen, "Échanges": the player's trades in three groups and one
# trade's board, read only, and the board's actions, each a POST to a Game
# operation that answers with a redirect to the board, the copy deck's toast
# or, for a refusal, the operation's message inline and in a toast.
#
# A trade is addressed by its token. On a desktop the list sits beside a
# board (the first trade's on the list itself); on a phone the list and the
# board are separate views (trades.css). A board waiting for the player
# carries the TradeBoard island, which turns it into a counter-proposal in
# place; the counter-proposal also has a page of its own (`edit`), where a
# refusal lands and which works without JavaScript. Each side takes any card
# its holder holds. A new trade starts as a draft (`new`) that lives in the
# browser until it is sent (`create`). Mutations are limited to 20 a minute
# per player.
class TradesController < ApplicationController
  rate_limit to: 20, within: 1.minute, only: %i[create counter accept decline cancel],
    by: -> { current_player&.id || request.remote_ip },
    with: -> { redirect_to trades_path, alert: t("trades.throttled"), status: :see_other }

  # Failures that the copy deck names "EXEMPLAIRES INSUFFISANTS".
  INSUFFICIENT = %i[requested_cards_unavailable insufficient_copies].freeze

  # GET /:locale/trades
  def index
    authorize :trade, :index?
    @trades = Game::TradesOf.call(current_player)
    @trade = @trades.first
    load_board(@trades, @trade)
  end

  # GET /:locale/trades/:token
  def show
    authorize :trade, :show?
    @trade = find_trade!
    @trades = Game::TradesOf.call(current_player)
    load_board(@trades, @trade)
  end

  # GET /:locale/trades/new?friend=<token>: the draft of a trade with a
  # friend, or, when the two already have an open trade, that trade's board
  # with the one-at-a-time refusal.
  def new
    authorize :trade, :new?
    @friend = tradable_friend(params[:friend]) or raise(ActiveRecord::RecordNotFound)
    @trades = Game::TradesOf.call(current_player)
    if (open = open_trade_with(@trades, @friend))
      one_at_a_time(@friend)
      return redirect_to(trade_path(token: open.token))
    end

    @cards = card_views(@trades, nil)
    load_holdings(@friend)
  end

  # POST /:locale/trades, with `friend` (their token), `give[<card key>]`
  # and `take[<card key>]`: the draft sent as a proposal.
  def create
    authorize :trade, :create?
    friend = tradable_friend(params[:friend])
    unless friend
      refused(:not_friends)
      return redirect_to(trades_path, status: :see_other)
    end

    result = with_sides(friend) do |offer, request|
      Game::ProposeTrade.new.call(player: current_player, recipient: friend, offer:, request:)
    end
    if result.success?
      flash[:trade_forget] = helpers.trade_draft_key(current_player, friend)
      toast t("trades.sent.title"), t("trades.sent.text", name: helpers.trade_friend_name(friend))
      redirect_to trade_path(token: result.value!.token), status: :see_other
    else
      refused(result.failure)
      redirect_to new_trade_path(friend: friend.token), status: :see_other
    end
  end

  # GET /:locale/trades/:token/counter: the counter-proposal form, only on
  # the player's turn (else the board).
  def edit
    authorize :trade, :counter?
    @trade = find_trade!
    unless @trade.state == :yours
      # A refused counter lands here first: its message goes on to the board.
      flash.keep
      return redirect_to(trade_path(token: @trade.token))
    end

    @trades = Game::TradesOf.call(current_player)
    @cards = card_views(@trades, @trade)
    load_holdings(@trade.friend)
    @own_max = @own_cards.transform_values(&:free)
    @own_held = @own_cards.transform_values(&:quantity)
    @friend_max = @friend_cards.transform_values(&:quantity)
  end

  # POST /:locale/trades/:token/counter, with `give[<card key>]` and
  # `take[<card key>]` quantities (0 removes the card): the player gives
  # cards they hold and asks for cards the friend holds.
  def counter
    authorize :trade, :counter?
    trade = find_trade!

    result = with_sides(trade.friend) do |offer, request|
      Game::CounterTrade.new.call(player: current_player, trade_id: trade.id, offer:, request:)
    end
    if result.success?
      flash[:trade_forget] = helpers.trade_counter_key(current_player, trade)
      toast t("trades.sent.title"), t("trades.sent.text", name: helpers.trade_friend_name(trade.friend))
      redirect_to trade_path(token: trade.token), status: :see_other
    else
      refused(result.failure)
      redirect_to counter_trade_path(token: trade.token), status: :see_other
    end
  end

  # POST /:locale/trades/:token/accept
  def accept
    authorize :trade, :accept?
    trade = find_trade!

    answer(trade, Game::AcceptTrade.new.call(player: current_player, trade_id: trade.id)) do
      cards = Catalog::CardViews.call(trade.friend_side.map(&:card_season_id), locale: I18n.locale)
      gained = trade.friend_side.filter_map { |line| helpers.trade_line_title(line, cards) }
      toast t("trades.accepted.title"), t("trades.accepted.text", count: gained.size, cards: gained.to_sentence)
      flash[:trade_swap] = true
    end
  end

  # POST /:locale/trades/:token/decline
  def decline
    authorize :trade, :decline?
    trade = find_trade!

    answer(trade, Game::DeclineTrade.new.call(player: current_player, trade_id: trade.id)) do
      toast t("trades.declined.title"), t("trades.declined.text", name: helpers.trade_friend_name(trade.friend))
    end
  end

  # POST /:locale/trades/:token/cancel
  def cancel
    authorize :trade, :cancel?
    trade = find_trade!

    answer(trade, Game::CancelTrade.new.call(player: current_player, trade_id: trade.id)) do
      toast t("trades.cancelled.title"), t("trades.cancelled.text")
    end
  end

  private
    # The player's trade named by the URL's token, or a 404.
    def find_trade!
      Game::TradesOf.find(current_player, params[:token]) || raise(ActiveRecord::RecordNotFound)
    end

    def tradable_friend(token)
      friend = Accounts::PlayerByToken.call(token)
      friend if tradable?(friend)
    end

    def tradable?(friend)
      friend.present? && !friend.banned? && !friend.deleted? && Game::FriendshipBetween.call(current_player, friend)
    end

    def open_trade_with(trades, friend)
      (trades.yours + trades.theirs).find { |row| row.friend.id == friend.id }
    end

    # The faces of every card the list and the board show, by card-season.
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
      when :closed then @trade_again = tradable?(trade.friend)
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
        refused(result.failure)
      end
      redirect_to trade_path(token: trade.token), status: :see_other
    end

    def toast(title, text)
      flash[:toast_title] = title
      flash[:notice] = text
    end

    def one_at_a_time(friend)
      flash[:trade_error] = t("trades.one_at_a_time.text", name: helpers.trade_friend_name(friend))
      flash[:toast_title] = t("trades.one_at_a_time.title")
      flash[:alert] = flash[:trade_error]
    end

    # The refusal's message, inline on the board and in a toast.
    def refused(code)
      message = Game::Operation.failure_message(code)
      flash[:trade_error] = message
      flash[:toast_title] = t("trades.insufficient") if INSUFFICIENT.include?(code)
      flash[:alert] = message
    end
end
