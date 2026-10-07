# What the trades screen writes about a trade (EXPERIENCE.md, Trade list row,
# Trade board; DESIGN.md, Trade board): the friend's name, a side in words
# ("Celeste ×2, Hades"), the status chip, the expiry and the outcome's age,
# and the key a card goes by in the counter form (AD-15: its slug and
# season number, never its id). Rows are Game::TradesOf rows; `cards` are
# Catalog::CardViews by card-season.
module TradesHelper
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
end
