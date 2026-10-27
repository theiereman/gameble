module TradesHelper
  COUNTER_FORM_ID = "trade-counter-form"
  DRAFT_FORM_ID = "trade-draft-form"
  FACES_PER_REQUEST = 36
  CARD_KEY = /\A(.+)--s(\d{1,9})\z/
  PICKER_CHIPS = { friend: %w[duplicates missing shared], own: %w[duplicates missing available] }.freeze
  BOARD_CHILDREN = %w[trade-board-send].freeze
  BOARD_ACTIONS = {
    "trade-board-side" => { add: :openPicker, remove: :removeLine, quantity: :setLineQuantity },
    "trade-board-picker" => { toggle: :togglePick, quantity: :setPickQuantity, filter: :setFilter, fold: :toggleFold,
                              clear: :clearFilters, more: :showMore, move: :moveActive, place: :place, close: :closePicker }
  }.freeze

  BoardPick = Data.define(:key, :view, :owned, :reserved, :max, :copies, :other_copies) do
    def unavailable? = max < 1
  end
  BoardLine = Data.define(:pick, :quantity) do
    def key = pick.key
    def view = pick.view
    def max = pick.max
  end

  def trades_refusal(friend)
    if !Game::Visibility.open_to_friends?(current_player) then :own_profile_private
    elsif !Game::Visibility.open_to_friends?(friend) then :friend_profile_private
    end
  end

  def trades_closed_line(refusal, friend)
    text = Game::Operation.failure_message(refusal, name: friend_name(friend))
    settings = link_to(t("trades.closed.settings"), settings_path, class: "trades-closed__link") if refusal == :own_profile_private
    tag.p(safe_join([ text, settings ].compact, " "), class: "trades-closed")
  end

  def trade_groups(trades)
    { yours: trades.yours, theirs: trades.theirs, recent: trades.recent }
  end

  def trade_line_title(line, cards)
    view = cards[line.card_season_id] or return
    line.quantity > 1 ? "#{view.title} ×#{line.quantity}" : view.title
  end

  def trade_side_title(lines, cards, open:)
    titles = lines.filter_map { |line| trade_line_title(line, cards) }
    return t("trades.row.to_choose") if lines.empty? && open

    titles.empty? ? "—" : titles.join(", ")
  end

  def trade_empty_side_label(side, friend)
    side == :own ? t("trades.side.for_friend_to_choose", name: friend_name(friend)) : t("trades.side.yours_to_choose")
  end

  def trade_open_help(friend)
    t("trades.board.open_help", name: friend_name(friend))
  end

  def trade_what_for_what(row, cards)
    t("trades.row.what_for_what", theirs: trade_side_title(row.friend_side, cards, open: row.open?),
      yours: trade_side_title(row.own_side, cards, open: row.open?))
  end

  def trade_chip(row)
    tone = { yours: "alert", theirs: "accent", concluded: "lime", closed: "muted" }.fetch(row.state)
    [ tone, t("trades.chip.#{row.state}") ]
  end

  def trade_days_left(row, now: Time.current)
    [ ((row.expires_at - now) / 1.day).ceil, 1 ].max
  end

  def trade_outcome_age(row, now: Time.current)
    t("trades.outcome.#{row.outcome}", age: trade_age(row.ended_at, now:))
  end

  def trade_age(time, now: Time.current)
    seconds = [ now - time, 0 ].max
    if seconds < 1.minute then t("trades.age.now")
    elsif seconds < 1.hour then t("trades.age.minutes", count: (seconds / 1.minute).floor)
    elsif seconds < 1.day then t("trades.age.hours", count: (seconds / 1.hour).floor)
    else t("trades.age.days", count: (seconds / 1.day).floor)
    end
  end

  def trade_side_labels(row)
    name = friend_name(row.friend)
    case row.state
    when :concluded then [ t("trades.side.friend_received", name:), t("trades.side.you_received") ]
    when :closed then [ t("trades.side.friend_offered", name:), t("trades.side.you_give") ]
    else [ t("trades.side.friend_gives", name:), t("trades.side.you_give") ]
    end
  end

  def trade_board_lines(row)
    row.state == :concluded ? [ row.own_side, row.friend_side ] : [ row.friend_side, row.own_side ]
  end

  def trade_message(row, editing: false)
    return t("trades.board.editing") if editing

    name = friend_name(row.friend)
    { yours: t("trades.board.yours", name:), theirs: t("trades.board.theirs", name:),
      concluded: t("trades.board.concluded"), closed: t("trades.board.closed") }.fetch(row.state)
  end

  def trade_side_count(lines)
    copies = lines.sum(&:quantity)
    cards = t("trade_board.strings.cards", count: lines.size)
    copies == lines.size ? cards : t("trade_board.strings.cards_copies", count: lines.size, cards:, copies:)
  end

  def trade_card_limit(side, held_copy)
    return 0 unless held_copy

    side == :own ? held_copy.free : held_copy.quantity
  end

  def trade_card_key(view)
    "#{view.id}--s#{view.season_number}"
  end

  def trade_card_key_parts(key)
    match = CARD_KEY.match(key) or return
    [ match[1], match[2].to_i ]
  end

  def trade_card_faces(views)
    views.to_h { |view| [ trade_card_key(view), render(CardComponent.new(card: view, size: :s)).to_str ] }
  end

  def trade_draft_key(player, friend) = "#{player.token}:#{friend.token}"
  def trade_counter_key(player, row) = "#{player.token}:#{row.token}:#{row.expires_at.to_i}"

  def trade_board_locals(trade, cards:, own_held: nil, friend_held: nil, picks: nil, editing: false, **locals)
    return {} unless trade

    editor = (trade_board_editor(trade.friend_side, trade.own_side, own_held:, friend_held:, picks:) if trade.state == :yours && own_held && friend_held && picks)
    locals.merge(editing:, editor:)
  end

  def trade_draft_editor(own_held:, friend_held:, picks:)
    trade_board_editor([], [], own_held:, friend_held:, picks:)
  end

  def trade_board_editor(friend_lines, own_lines, own_held:, friend_held:, picks:)
    {
      friend: trade_board_side(:friend, held: friend_held, other_held: own_held, picks:, received: friend_lines),
      own: trade_board_side(:own, held: own_held, other_held: friend_held, picks:, received: own_lines),
      faces: (friend_lines + own_lines).filter_map { picks[it.card_season_id] }.uniq
    }
  end

  def trade_board_root_data(focus:, editing:, editor: nil, draft_key: nil, counter_url: nil, board_url: nil, forget: nil, swap: false)
    data = { controller: "trade-board", trade_board_editing_value: editing, trade_board_focus_value: focus,
             trade_board_forget_value: forget, trade_board_swap_value: (true if swap) }
    return data unless editor

    data.merge(
      action: screen_actions("trade-board", BOARD_ACTIONS), trade_board_draft_key_value: draft_key,
      trade_board_counter_url_value: counter_url, trade_board_board_url_value: board_url,
      trade_board_faces_url_value: faces_trades_path, trade_board_faces_batch_value: FACES_PER_REQUEST,
      trade_board_strings_value: screen_strings("trade_board.strings")
    ).merge(screen_outlets("trade-board", BOARD_ACTIONS.keys + BOARD_CHILDREN))
  end

  def trade_board_stepper(title:, value:, max:)
    { value:, max:, label: t("trade_board.strings.quantity_label", title:),
      value_text: t("trade_board.strings.value_text", count: value, max:),
      max_text: t("trade_board.strings.max", max:), max_phone_text: t("trade_board.strings.max_phone", max:) }
  end

  def trade_pick_label(pick)
    [ t("trade_board.card_label", title: pick.view.title, owned: t("trade_board.owned", count: pick.owned)),
      (t("trade_board.reserved_elsewhere", count: pick.reserved) if pick.reserved.positive?),
      (t("trade_board.unavailable") if pick.unavailable?) ].compact.join(", ")
  end

  def trade_picker_none(side, friend)
    side == :own ? t("trades.side.none.none_owned") : t("trades.side.none.friend_none_owned", name: friend_name(friend))
  end

  private
    def trade_board_side(side, held:, other_held:, picks:, received:)
      copies = trade_game_copies(held, picks)
      other_copies = trade_game_copies(other_held, picks)
      views = held.keys.filter_map { |id| picks[id] && [ id, picks[id] ] }
      views.sort_by! { |_, view| [ view.season_number, view.number ? 0 : 1, view.number.to_i, view.title ] }
      by_id = views.to_h do |id, view|
        row = held.fetch(id)
        [ id, BoardPick.new(key: trade_card_key(view), view:, owned: row.quantity, reserved: side == :own ? row.reserved : 0,
          max: trade_card_limit(side, row), copies: copies[view.id], other_copies: other_copies[view.id]) ]
      end
      { picks: by_id.values, lines: trade_board_initial_lines(received, by_id) }
    end

    def trade_board_initial_lines(received, picks_by_id)
      received.each_with_object([]) do |line, lines|
        pick = picks_by_id[line.card_season_id]
        next if pick.nil? || pick.unavailable? || lines.any? { it.key == pick.key } || lines.size >= Game::TradeItem::MAX_CARDS_PER_SIDE

        lines << BoardLine.new(pick:, quantity: line.quantity.clamp(1, pick.max))
      end
    end

    def trade_game_copies(held, picks)
      held.each_with_object(Hash.new(0)) do |(id, row), games|
        view = picks[id] or next
        games[view.id] += row.quantity
      end
    end
end
