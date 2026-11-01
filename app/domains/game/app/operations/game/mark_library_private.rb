module Game
  class MarkLibraryPrivate < Operation
    include CustomSetSteps

    def call(player:, token:)
      player = step require_player(player)

      transaction do
        step lock_bank(player)
        library_set = locked_library_set(player, token)
        marked(player, library_set) if library_set && library_set.library_private_since.nil?
        library_set
      end
    end

    private

    def marked(player, library_set)
      library_set.update!(library_private_since: Time.current)
      step published(LibrarySetMarkedPrivate, player, library_set)
    end
  end
end
