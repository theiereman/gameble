# What the trades screen writes about a trade: the friend's name, a side in
# words ("Celeste ×2, Hades"), the status chip, the expiry and the outcome's
# age, the key a card goes by in the counter form (its slug and season
# number, never its id), and the props of the TradeBoard island with the
# keys its edits are kept under in the browser. Rows are Game::TradesOf
# rows; `cards` are Catalog::CardViews by card-season.
module TradesHelper
  COUNTER_FORM_ID = "trade-counter-form"
  DRAFT_FORM_ID = "trade-draft-form"

  # The list's groups, in order, with the rows of each.
  def trade_groups(trades)
    { yours: trades.yours, theirs: trades.theirs, recent: trades.recent }
  end

  def trade_friend_name(friend)
    Accounts::PersonaName.clean(friend&.persona_name) || t("friends.show.nameless")
  end

  # "Celeste ×2", or nil when the card has no face.
  def trade_line_title(line, cards)
    view = cards[line.card_season_id] or return
    line.quantity > 1 ? "#{view.title} ×#{line.quantity}" : view.title
  end

  # "Celeste ×2, Hades", or "—" for an empty side.
  def trade_side_title(lines, cards)
    titles = lines.filter_map { |line| trade_line_title(line, cards) }
    titles.empty? ? "—" : titles.join(", ")
  end

  # "Hades contre Celeste ×2": what the friend gives for what the player gives.
  def trade_what_for_what(row, cards)
    t("trades.row.what_for_what", theirs: trade_side_title(row.friend_side, cards), yours: trade_side_title(row.own_side, cards))
  end

  # The status chip's tone and label.
  def trade_chip(row)
    tone = { yours: "alert", theirs: "accent", concluded: "lime", closed: "muted" }.fetch(row.state)
    [ tone, t("trades.chip.#{row.state}") ]
  end

  # Whole days left before the expiry, rounded up (at least 1 while open).
  def trade_days_left(row, now: Time.current)
    [ ((row.expires_at - now) / 1.day).ceil, 1 ].max
  end

  # "refusé il y a 4 j", "conclu à l'instant".
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

  # The side labels, friend's first: "LÉA DONNE" / "VOUS DONNEZ", "LÉA A
  # REÇU" / "VOUS AVEZ REÇU" once concluded, "LÉA PROPOSAIT" once closed.
  def trade_side_labels(row)
    name = trade_friend_name(row.friend)
    case row.state
    when :concluded then [ t("trades.side.friend_received", name:), t("trades.side.you_received") ]
    when :closed then [ t("trades.side.friend_offered", name:), t("trades.side.you_give") ]
    else [ t("trades.side.friend_gives", name:), t("trades.side.you_give") ]
    end
  end

  def trade_board_lines(row)
    row.state == :concluded ? [ row.own_side, row.friend_side ] : [ row.friend_side, row.own_side ]
  end

  # The board's one-line status message.
  def trade_message(row, editing: false)
    return t("trades.board.editing") if editing

    name = trade_friend_name(row.friend)
    { yours: t("trades.board.yours", name:), theirs: t("trades.board.theirs", name:),
      concluded: t("trades.board.concluded"), closed: t("trades.board.closed") }.fetch(row.state)
  end

  # "1 carte", "2 cartes · 3 ex.": a side's count.
  def trade_side_count(lines)
    copies = lines.sum(&:quantity)
    if copies == lines.size
      t("trades.side.cards", count: lines.size)
    else
      t("trades.side.cards_copies", count: lines.size, cards: t("trades.side.cards", count: lines.size), copies:)
    end
  end

  # Why a side of the counter form has no copy left to place, or nil
  # (EXPERIENCE.md, Nothing to place): `max` is the copies each card may
  # take (Game::FreeCopies for the player, Game::Quantities for the friend),
  # `held` the player's own copies, reserved ones included (nil for the
  # friend's side). The player holds none of them, or holds them all
  # reserved in other trades; the friend holds none any more.
  def trade_nothing_to_place(row, side, max, held = nil)
    lines = side == :own ? row.own_side : row.friend_side
    return if max.nil? || lines.empty? || lines.any? { |line| max.fetch(line.card_season_id, 0).positive? }

    if side == :friend then t("trades.side.none.friend_none_owned", name: trade_friend_name(row.friend))
    elsif lines.any? { |line| held.to_h.fetch(line.card_season_id, 0).positive? } then t("trades.side.none.all_reserved")
    else t("trades.side.none.none_owned")
    end
  end

  # The counter form's name for a card: its slug and its season's number.
  def trade_card_key(view)
    "#{view.id}--s#{view.season_number}"
  end

  def trade_draft_key(player, friend) = "#{player.token}:#{friend.token}"
  def trade_counter_key(player, row) = "#{player.token}:#{row.token}:#{row.expires_at.to_i}"

  def trade_board_locals(trade, cards:, own_held: nil, friend_held: nil, picks: nil, editing: false, **locals)
    return {} unless trade

    island = if trade.state == :yours && own_held && friend_held && picks
      trade_board_props(trade, own_held:, friend_held:, picks:, cards:, editing:, error: flash[:trade_error])
    end
    locals.merge(editing:, island:)
  end

  def trade_board_props(trade, own_held:, friend_held:, picks:, cards:, editing:, error: nil)
    name = trade_friend_name(trade.friend)
    friend_label, own_label = trade_side_labels(trade)
    trade_island_props(
      sides: [
        trade_island_side(:friend, label: friend_label, name:, held: friend_held, lines: trade.friend_side, picks:,
          read_html: trade_read_side(trade, :friend, label: friend_label, cards:)),
        trade_island_side(:own, label: own_label, name:, held: own_held, lines: trade.own_side, picks:,
          read_html: trade_read_side(trade, :own, label: own_label, cards:))
      ],
      message: trade_message(trade, editing: true), read_message: trade_message(trade),
      editing:, draft_key: trade_counter_key(current_player, trade), form_id: COUNTER_FORM_ID, error:
    )
  end

  def trade_draft_props(friend, own_held:, friend_held:, picks:, error: nil)
    name = trade_friend_name(friend)
    trade_island_props(
      sides: [
        trade_island_side(:friend, label: t("trades.side.friend_gives", name:), name:, held: friend_held, lines: [], picks:),
        trade_island_side(:own, label: t("trades.side.you_give"), name:, held: own_held, lines: [], picks:)
      ],
      message: t("trades.board.choose"), read_message: nil,
      editing: true, draft_key: trade_draft_key(current_player, friend), form_id: DRAFT_FORM_ID, error:
    )
  end

  private
    def trade_island_props(sides:, message:, read_message:, editing:, draft_key:, form_id:, error:)
      {
        sides:, message:, readMessage: read_message, editing:, draftKey: draft_key, formId: form_id, error:,
        swapIcon: pixel_icon("swap", class: "trade-board__swap").to_str,
        closeIcon: pixel_icon("close", class: "trade-island__close-icon").to_str,
        strings: trade_island_strings
      }
    end

    def trade_read_side(trade, side, label:, cards:)
      lines = side == :own ? trade.own_side : trade.friend_side
      render("trades/side", side:, label:, lines:, cards:, editing: false, reserved: side == :friend).to_str
    end

    def trade_island_side(side, label:, name:, held:, lines:, picks:, read_html: nil)
      own = side == :own
      views = held.keys.filter_map { |id| picks[id] && [ id, picks[id] ] }
      views.sort_by! { |_, view| [ view.season_number, view.number ? 0 : 1, view.number.to_i, view.title ] }
      {
        side:, field: own ? "give" : "take", label:, readHtml: read_html,
        add: t("trades.island.add.#{side}"),
        pickerTitle: t("trades.island.picker.#{side}", name:),
        pickerTitleShort: t("trades.island.picker_short.#{side}", name:),
        note: t("trades.island.note.#{side}", name:),
        none: own ? t("trades.side.none.none_owned") : t("trades.side.none.friend_none_owned", name:),
        cards: views.map do |id, view|
          row = held.fetch(id)
          { key: trade_card_key(view), title: view.title, owned: row.quantity, reserved: own ? row.reserved : 0,
            max: own ? row.free : row.quantity, face: render(CardComponent.new(card: view, size: :s)).to_str }
        end,
        lines: lines.filter_map { |line| (view = picks[line.card_season_id]) && { key: trade_card_key(view), quantity: line.quantity } }
      }
    end

    def trade_island_strings
      t("trades.island.strings").deep_transform_keys { it.to_s.camelize(:lower) }.merge(
        editing: t("trades.chip.editing"), cards: t("trades.side.cards"), cardsCopies: t("trades.side.cards_copies"),
        copiesLabel: t("trades.side.copies_label"), reserved: t("trades.side.reserved"),
        quantity: t("trades.side.quantity_label"), max: t("trades.side.max"),
        noneTitle: t("trades.side.none.title"), noneAllReserved: t("trades.side.none.all_reserved")
      )
    end
end
