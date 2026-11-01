module Game
  class SyncLibrarySet < Operation
    include CustomSetSteps

    def call(player:, token:, card_ids:)
      player = step require_player(player)
      card_ids = Catalog::PublishedCardIds.within(Array(card_ids))

      transaction do
        step lock_bank(player)
        library_set = locked_library_set(player, token)
        synced(player, library_set, card_ids) if library_set
        library_set
      end
    end

    private

    def synced(player, library_set, card_ids)
      changed = replace_games(library_set, card_ids)
      library_set.update!(synced_at: Time.current, library_private_since: nil)
      step published(LibrarySetSynced, player, library_set) if changed
    end

    def replace_games(library_set, card_ids)
      games = CustomSetGame.where(custom_set_id: library_set.id)
      listed = games.pluck(:card_id)
      gone = listed - card_ids
      added = card_ids - listed
      games.where(card_id: gone).delete_all if gone.any?
      CustomSetGame.insert_all!(added.map { |card_id| { custom_set_id: library_set.id, card_id: } }) if added.any?
      gone.any? || added.any?
    end
  end
end
