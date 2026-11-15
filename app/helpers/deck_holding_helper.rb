module DeckHoldingHelper
  def deck_removal_ref(view) = Game::Market::EntrustableCopies.ref(view.id, view.season_number)

  def deck_removal_dialog_id(ref) = "deck-removal-#{ref.sub(":", "--s")}"

  def deck_holding_names(names) = t("decks.holding.names", decks: names.join(", "))

  def deck_holding_words(names) = t("decks.holding.words", decks: names.join(", "))
end
