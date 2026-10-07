# The trades screen, "Échanges" (CAP-11; EXPERIENCE.md, Échanges, Trade
# board; story 5.6): the player's trades in three groups and one trade's
# board, read only (AD-11), and the board's actions, each a POST to a Game
# operation that answers with a redirect to the board, the copy deck's toast
# or, for a refusal, the operation's message inline and in a toast.
#
# A trade is addressed by its token (AD-15). On a desktop the list sits
# beside a board (the first trade's on the list itself); on a phone the list
# and the board are separate views (trades.css). Until the trade board island
# (stories 5.7, 5.8), a counter-proposal edits the quantities of the cards
# already on each side, a form of its own (`edit`). Mutations are limited to
# 20 a minute per player.
class TradesController < ApplicationController
  rate_limit to: 20, within: 1.minute, only: %i[counter accept decline cancel],
    by: -> { current_player&.id || request.remote_ip },
    with: -> { redirect_to trades_path, alert: t("trades.throttled"), status: :see_other }

  # Failures that the copy deck names "EXEMPLAIRES INSUFFISANTS".
  INSUFFICIENT = %i[requested_cards_unavailable insufficient_copies].freeze

  # GET /:locale/trades
  def index
    authorize :trade, :index?
    @trades = Game::TradesOf.call(current_player)
    @trade = @trades.first
    @cards = card_views(@trades, @trade)
  end

  # GET /:locale/trades/:token
  def show
    authorize :trade, :show?
    @trade = find_trade!
    @trades = Game::TradesOf.call(current_player)
    @cards = card_views(@trades, @trade)
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
    own = @trade.own_side.map(&:card_season_id)
    @own_max = Game::FreeCopies.call(current_player, own)
    @own_held = Game::Quantities.call(current_player, own)
    @friend_max = Game::Quantities.call(@trade.friend, @trade.friend_side.map(&:card_season_id))
  end

  # POST /:locale/trades/:token/counter, with `give[<card key>]` and
  # `take[<card key>]` quantities (0 removes the card).
  def counter
    authorize :trade, :counter?
    trade = find_trade!
    cards = Catalog::CardViews.call(trade.card_season_ids, locale: I18n.locale)
    offer = quantities(params[:give], trade.own_side, cards)
    request = quantities(params[:take], trade.friend_side, cards)

    result = Game::CounterTrade.new.call(player: current_player, trade_id: trade.id, offer:, request:)
    if result.success?
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

    # The faces of every card the list and the board show, by card-season.
    def card_views(trades, trade)
      rows = [ trades.yours, trades.theirs, trades.recent, [ trade ] ].flatten.compact
      Catalog::CardViews.call(rows.flat_map(&:card_season_ids), locale: I18n.locale)
    end

    # The quantities a side of the counter form sends, by card-season: only
    # the cards already on that side (no picker yet), 0 or blank removing
    # one. A value that is no number is kept, for CounterTrade to refuse.
    def quantities(fields, lines, cards)
      fields = fields.respond_to?(:to_unsafe_h) ? fields.to_unsafe_h : {}
      lines.each_with_object({}) do |line, side|
        view = cards[line.card_season_id] or next
        value = fields[helpers.trade_card_key(view)].to_s.strip
        side[line.card_season_id] = value unless value.empty? || value == "0"
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

    # The refusal's message, inline on the board and in a toast.
    def refused(code)
      message = Game::Operation.failure_message(code)
      flash[:trade_error] = message
      flash[:toast_title] = t("trades.insufficient") if INSUFFICIENT.include?(code)
      flash[:alert] = message
    end
end
