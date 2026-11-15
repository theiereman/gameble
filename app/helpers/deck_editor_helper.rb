module DeckEditorHelper
  DECK_EDITOR_ACTIONS = {
    "deck-name" => { rename: :rename },
    "deck-slots" => { remove: :removeSlot },
    "deck-collection" => { choose: :choose, move: :move }
  }.freeze

  def deck_editor_root_data(editor)
    deck = editor.deck
    { controller: "deck-editor", action: screen_actions("deck-editor", DECK_EDITOR_ACTIONS),
      deck_editor_token_value: deck&.token.to_s, deck_editor_name_value: deck&.name.to_s,
      deck_editor_create_url_value: decks_path, deck_editor_deck_url_value: deck ? deck_path(token: deck.token) : "",
      deck_editor_strings_value: deck_editor_strings }
      .merge(screen_outlets("deck-editor", DECK_EDITOR_ACTIONS.keys))
  end

  def deck_entry_data(editor, entry)
    { ref: entry.ref, game: entry.game, title: entry.title, image: entry.image_url, availability: entry.availability,
      label: deck_entry_label(entry) }
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

  private
    def deck_editor_strings
      screen_strings("decks.editor.strings").merge(
        notYetRanked: Game::AddCardToDeck.failure_message(:not_yet_ranked),
        noFreeCopy: Game::AddCardToDeck.failure_message(:no_free_copy))
    end
end
