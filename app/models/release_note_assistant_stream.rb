# The stream one open release-note editor listens on for Claude's answers: it belongs to the administrator
# who opened the page and to that page alone, so an answer never fills another tab's note.
module ReleaseNoteAssistantStream
  PAGE = /\A\h{8}-\h{4}-\h{4}-\h{4}-\h{12}\z/

  class << self
    def new_page = SecureRandom.uuid

    def page?(page) = PAGE.match?(page.to_s)

    def streamables(player, page) = [ "release-note-assistant", player.stream_key, page ]
  end
end
