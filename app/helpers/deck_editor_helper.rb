module DeckEditorHelper
  DECK_EDITOR_ACTIONS = {
    "deck-name" => { rename: :rename },
    "deck-coverage" => { gap: :chooseGap },
    "deck-slots" => { remove: :removeSlot },
    "deck-collection" => { choose: :choose, move: :move, sort: :sortBy, filter: :filterBy, more: :more, search: :search }
  }.freeze

  def deck_editor_root_data(editor)
    deck = editor.deck
    { controller: "deck-editor", action: screen_actions("deck-editor", DECK_EDITOR_ACTIONS),
      deck_editor_token_value: deck&.token.to_s, deck_editor_name_value: deck&.name.to_s,
      deck_editor_create_url_value: decks_path, deck_editor_deck_url_value: deck ? deck_path(token: deck.token) : "",
      deck_editor_strings_value: deck_editor_strings,
      deck_editor_coverage_value: deck_coverage_json(editor.coverage) }
      .merge(screen_outlets("deck-editor", DECK_EDITOR_ACTIONS.keys))
  end

  def deck_entry_data(editor, entry)
    { ref: entry.ref, game: entry.game, title: entry.title, image: entry.image_url, availability: entry.availability,
      label: deck_entry_label(entry), percentiles: entry.percentiles, trump: entry.trump_stat.to_s,
      moves_text: deck_moves_text(entry), moves_sentence: deck_moves_sentence(entry) }
  end

  StatBar = Data.define(:stat, :value, :tier, :trump)

  def deck_entry_bars(entry)
    Game::DuelStat::STATS.filter_map do |stat|
      percentile = entry.percentiles[stat] or next
      value = percentile.round.clamp(0, 99)
      StatBar.new(stat:, value:, tier: deck_stat_tier(value), trump: entry.trump_stat == stat)
    end
  end

  def deck_blank_bars = Game::DuelStat::STATS.map { StatBar.new(stat: it, value: 0, tier: "mid", trump: false) }

  def deck_stat_tier(value)
    if value >= 90 then "highest"
    elsif value >= 70 then "high"
    elsif value <= 10 then "lowest"
    elsif value <= 30 then "low"
    else "mid"
    end
  end

  def deck_entry_label(entry)
    [ entry.title, SeasonMarkComponent.label(entry.season_number), deck_entry_detail(entry) ].join(", ")
  end

  def deck_entry_detail(entry)
    case entry.availability
    when :unranked then t("decks.editor.no_stats")
    when :reserved then t("trades.side.reserved", count: 1)
    else deck_entry_trump(entry)
    end
  end

  def deck_entry_trump(entry)
    return t("decks.editor.no_stats") if entry.trump_stat.nil?

    t("decks.editor.trump", trump: t("duel_stats.trump"), stat: t("duel_stats.names.#{entry.trump_stat}"))
  end

  def deck_slot_label(entry)
    [ t("decks.editor.strings.remove_slot", card: entry&.title), deck_moves_sentence(entry).presence ].compact.join(". ")
  end

  def deck_moves_text(entry)
    Array(entry&.moves).map { "#{it.up? ? "▲" : "▼"} #{t("duel_stats.short.#{it.stat}")}" }.join(" ")
  end

  def deck_moves_sentence(entry)
    Array(entry&.moves).map do |move|
      t("decks.editor.moves.#{move.up? ? "up" : "down"}", stat: t("duel_stats.names.#{move.stat}"), to: move.to, from: move.from)
    end.join(". ")
  end

  def deck_coverage_json(coverage)
    coverage.calls.map { { call: it.key, best: it.shown, gap: it.gap?, many: it.many? } }
  end

  def deck_call_label(call) = t("duel_stats.directions.#{call.stat}.#{call.direction}")

  def deck_call_cards(call) = t("decks.editor.coverage.cards.#{call.stat}.#{call.direction}")

  def deck_sort_options
    calls = Game::DeckCoverage::CALLS.map { |stat, direction| [ t("duel_stats.directions.#{stat}.#{direction}"), Game::DeckCoverage.key(stat, direction) ] }
    [ [ t("decks.editor.sort.by_title"), "title" ], *calls ]
  end

  def deck_sort_links
    deck_sort_options.map { |label, key| { label:, href: "#{request.path}?sort=#{key}", current: key == "popularity-high" } }
  end

  def deck_trump_options
    [ [ t("decks.editor.trump_filter.all"), "all" ], *Game::DuelStat::STATS.map { [ t("duel_stats.names.#{it}"), it.to_s ] } ]
  end

  private
    def deck_editor_strings
      screen_strings("decks.editor.strings").merge(
        notYetRanked: Game::AddCardToDeck.failure_message(:not_yet_ranked),
        noFreeCopy: Game::AddCardToDeck.failure_message(:no_free_copy),
        calls: deck_sort_options.drop(1).to_h(&:reverse))
    end
end
