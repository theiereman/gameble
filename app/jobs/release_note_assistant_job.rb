# Asks Claude for the release-note editor outside the web request, then sends the answer, or why there is
# none, to the editor page that asked.
class ReleaseNoteAssistantJob < ApplicationJob
  queue_as :default

  rescue_from(StandardError) do |error|
    refuse(arguments.first, :unavailable)
    raise error
  end

  private

  def answer(stream, partial, **locals)
    content = ApplicationController.render(partial: "back_office/release_notes/#{partial}", formats: [ :turbo_stream ], locals:)
    Turbo::StreamsChannel.broadcast_stream_to(*stream, content:)
  end

  def refuse(stream, code)
    answer(stream, "assistant_failure", code:)
  end
end
