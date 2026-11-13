class TranslateReleaseNoteJob < ReleaseNoteAssistantJob
  def perform(stream, texts, preview_locale)
    translation = Accounts::ClaudeWriter.translate(title: texts[:title_fr], body: texts[:body_fr])
    return refuse(stream, :unavailable) unless translation

    answer(stream, "translated", texts: texts.merge(title_en: translation[:title], body_en: translation[:body]), preview_locale:)
  end
end
