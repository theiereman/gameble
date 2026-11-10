require "anthropic"

module Accounts
  # The back office's writing help: Claude translates a French release note or roadmap lines into English, and
  # condenses a release's commits into a French note. Each answer follows a JSON schema; nil when no API key is
  # set, the API fails or Claude declines.
  class ClaudeWriter
    MODEL = :"claude-opus-5-5"
    FALLBACK_BETA = "server-side-fallback-2026-07-01".freeze
    MAX_TOKENS = 16_000
    TIMEOUT = 80

    TRANSLATION_SCHEMA = {
      type: "object", additionalProperties: false, required: %w[title body],
      properties: { title: { type: "string" }, body: { type: "string" } }
    }.freeze

    WORDINGS_SCHEMA = {
      type: "object", additionalProperties: false, required: %w[translations],
      properties: { translations: { type: "array", items: {
        type: "object", additionalProperties: false, required: %w[key english],
        properties: { key: { type: "string" }, english: { type: "string" } }
      } } }
    }.freeze

    CONDENSED_SCHEMA = {
      type: "object", additionalProperties: false, required: %w[title intro lines dropped],
      properties: {
        title: { type: "string" },
        intro: { type: "string" },
        lines: { type: "array", items: {
          type: "object", additionalProperties: false, required: %w[section text sources],
          properties: { section: { type: "string", enum: CondensedChanges::SECTIONS },
                        text: { type: "string" }, sources: { type: "array", items: { type: "string" } } }
        } },
        dropped: { type: "array", items: {
          type: "object", additionalProperties: false, required: %w[source reason],
          properties: { source: { type: "string" }, reason: { type: "string" } }
        } }
      }
    }.freeze

    def self.available?
      api_key.present?
    end

    # { title:, body: } in English, or nil.
    def self.translate(title:, body:)
      answer = ask(system: translation_brief, prompt: "Title:\n#{title}\n\nBody:\n#{body}", schema: TRANSLATION_SCHEMA, effort: :low)
      answer && { title: answer["title"].to_s.squish, body: ReleaseNote.clean_body(answer["body"]) }
    end

    # { key => English } for the given { key => French } roadmap lines, or nil.
    def self.translate_wordings(wordings, length:)
      prompt = wordings.map { |key, french| "#{key}: #{french.squish}" }.join("\n")
      answer = ask(system: wordings_brief(length), prompt:, schema: WORDINGS_SCHEMA, effort: :low)
      answer && Array(answer["translations"]).to_h { [ it["key"].to_s, it["english"].to_s.squish ] }.slice(*wordings.keys)
    end

    # A CondensedChanges, or nil.
    def self.condense(changes)
      sources = CondensedChanges.sources_of(changes)
      prompt = sources.map { "#{it.id} [#{it.section}] #{it.change.subject}" }.join("\n")
      answer = ask(system: condensing_brief, prompt:, schema: CONDENSED_SCHEMA, effort: :medium)
      answer && CondensedChanges.new(changes, answer)
    end

    # The parsed JSON answer, or nil.
    def self.ask(system:, prompt:, schema:, effort:)
      return unless available?

      message = client.beta.messages.create(
        model: MODEL, max_tokens: MAX_TOKENS, betas: [ FALLBACK_BETA ], fallbacks: :default,
        output_config: { effort:, format_: { type: :json_schema, schema: } },
        system_: [ { type: :text, text: system } ], messages: [ { role: :user, content: prompt } ]
      )
      return unless message.stop_reason == :end_turn

      text = message.content.find { it.type == :text }&.text
      text && JSON.parse(text)
    rescue Anthropic::Errors::Error, JSON::ParserError => error
      Rails.logger.warn("Claude could not write the release note: #{error.class}: #{error.message}")
      nil
    end

    def self.client
      Anthropic::Client.new(api_key:, timeout: TIMEOUT, max_retries: 1)
    end

    def self.api_key
      Rails.configuration.x.anthropic.api_key
    end

    def self.translation_brief
      <<~BRIEF
        You translate the French release notes of Gameble, a free web trading card game where every card is a Steam game, into English for its players.
        Write natural, friendly English with the same meaning, tone and length; do not translate word for word.
        Keep the format exactly: a line starting with "## " is a section heading, a line starting with "- " is an item, a blank line separates paragraphs. Keep every line where it is.
        Keep @logins, version numbers, game titles and figures unchanged.
        Translate these section headings and phrasings as given: #{section_glossary}.
        The game's own words, French = English: #{screen_glossary}.
        An empty title or body stays empty.
      BRIEF
    end

    def self.wordings_brief(length)
      <<~BRIEF
        You translate the public roadmap of Gameble, a free web trading card game where every card is a Steam game, from French into English for its players.
        You get one roadmap line per line, as "key: French". Answer every key with its English: natural, short, the same meaning and tone, never longer than #{length} characters.
        Keep game titles, version numbers and figures unchanged.
        The game's own words, French = English: #{screen_glossary}.
      BRIEF
    end

    def self.condensing_brief
      <<~BRIEF
        You write the release notes Gameble players read after an update. Gameble is a free web trading card game where every card is a Steam game; players open capsules (boosters), complete sets, trade with friends, and use a web app and native iPhone and Android apps.
        You get the release's commits, one per line, as "id [section] subject"; "features" are new things, "fixes" are corrections. Commit subjects are terse developer English.
        Write in French, for players, not developers: plain sentences that say what changed for them, in the vous form, with French typography (a narrow no-break space before : ; ? ! and inside « »).
        Keep what matters to a player and merge commits that describe the same change into one line. Drop a commit when it repeats another one, only touches the code, tests, tooling or the back office, or is too small for a player to notice; give the reason in a few French words.
        Every commit id must appear either in the sources of a line or in dropped, never both, and never invented.
        Lines carry no credits, no @logins and no leading "- "; they are added afterwards. Keep each line under 160 characters and the whole note under 1,200 characters.
        title: a short French headline of the release's main change, under 70 characters. intro: one French sentence summing up the release, or "" when the lines say it all.
        The game's own words, French = English: #{screen_glossary}.
      BRIEF
    end

    def self.section_glossary
      sections = ReleaseChanges::SECTIONS.keys.map do |section|
        "\"## #{I18n.t("release_notes.sections.#{section}", locale: :fr)}\" = \"## #{I18n.t("release_notes.sections.#{section}", locale: :en)}\""
      end
      credited = %i[fr en].map { "\"#{I18n.t("release_notes.credited", locale: it, change: "…", people: "@login")}\"" }.join(" = ")
      [ *sections, credited ].join(", ")
    end

    def self.screen_glossary
      I18n.t("shell.screens", locale: :fr).map { |key, french| "#{french} = #{I18n.t("shell.screens.#{key}", locale: :en)}" }.join(", ")
    end

    private_class_method :api_key, :translation_brief, :wordings_brief, :condensing_brief, :section_glossary, :screen_glossary
  end
end
