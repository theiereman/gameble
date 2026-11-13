class CondenseReleaseNoteJob < ReleaseNoteAssistantJob
  def perform(stream, token)
    version = Accounts::ReleaseNotes.by_token(token)&.release_version
    changes = version && Accounts::GithubReleaseChanges.for(version)
    return refuse(stream, :no_changes) if changes.nil? || changes.empty?

    condensed = Accounts::ClaudeWriter.condense(changes)
    return refuse(stream, :unavailable) unless condensed

    answer(stream, "condensed", condensed:)
  end
end
