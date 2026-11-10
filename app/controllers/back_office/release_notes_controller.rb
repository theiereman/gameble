module BackOffice
  class ReleaseNotesController < BaseController
    PREVIEW_ID = "release-note-preview".freeze
    ASSISTANT_STATUS_ID = "release-note-assistant-status".freeze
    REVIEW_ID = "release-note-review".freeze

    rate_limit to: 30, within: 1.minute, only: %i[create save state], name: "save"
    rate_limit to: 240, within: 1.minute, only: :preview, name: "preview"
    rate_limit to: 10, within: 1.minute, only: %i[translate condense], name: "claude"

    def index
      authorize [ :back_office, :release_notes ], :index?
      @release_notes = Accounts::ReleaseNotes.newest_first
      @read_counts = Accounts::ReleaseNotes.read_counts(@release_notes)
      @live = Accounts::ReleaseNotes.live(running: running_release)
      @suggested_version = Accounts::ReleaseNotes.missing(running: running_release)
    end

    def create
      authorize [ :back_office, :release_notes ], :create?

      if (existing = Accounts::ReleaseNotes.by_version(params[:version]))
        return skipping? ? change_state(existing, "skipped") : redirect_to(edit_back_office_release_note_path(token: existing.token), status: :see_other)
      end

      skipping? ? create_skipped : create_draft
    end

    def edit
      authorize [ :back_office, :release_notes ], :edit?
      @release_note = release_note
      @texts = @release_note.texts
      @preview_locale = preview_locale
    end

    def save
      authorize [ :back_office, :release_notes ], :save?
      @release_note = release_note

      result = Accounts::EditReleaseNote.new.call(staff: current_player, release_note: @release_note, **sent_texts)
      if result.success?
        redirect_to edit_back_office_release_note_path(token: @release_note.token), notice: t(".saved"), status: :see_other
      else
        @failure = Accounts::EditReleaseNote.failure_message(result.failure)
        @texts = sent_texts
        @preview_locale = preview_locale
        render :edit, status: :unprocessable_content
      end
    end

    def preview
      authorize [ :back_office, :release_notes ], :preview?
      texts = Accounts::ReleaseNote.clean(sent_texts)
      locale = preview_locale
      component = ReleaseNoteComponent.new(title: texts[:"title_#{locale}"], body: texts[:"body_#{locale}"], locale:)
      render turbo_stream: turbo_stream.update(PREVIEW_ID, component)
    end

    def state
      authorize [ :back_office, :release_notes ], :state?
      change_state(release_note, params[:state])
    end

    def translate
      authorize [ :back_office, :release_notes ], :translate?
      @texts = Accounts::ReleaseNote.clean(sent_texts)
      return assistant_failure(:nothing_to_translate) if @texts[:title_fr].blank? && @texts[:body_fr].blank?

      translation = Accounts::ClaudeWriter.translate(title: @texts[:title_fr], body: @texts[:body_fr])
      return assistant_failure(:unavailable) unless translation

      @texts = @texts.merge(title_en: translation[:title], body_en: translation[:body])
      render turbo_stream: [
        turbo_stream.replace("release-note-language-en", partial: "language", locals: { locale: "en", texts: @texts }),
        turbo_stream.update(PREVIEW_ID, ReleaseNoteComponent.new(title: @texts[:"title_#{preview_locale}"], body: @texts[:"body_#{preview_locale}"], locale: preview_locale)),
        assistant_status(t("back_office.release_notes.assistant.translated"))
      ]
    end

    def condense
      authorize [ :back_office, :release_notes ], :condense?
      changes = release_note.release_version&.then { Accounts::GithubReleaseChanges.for(it) }
      return assistant_failure(:no_changes) if changes.nil? || changes.empty?

      condensed = Accounts::ClaudeWriter.condense(changes)
      return assistant_failure(:unavailable) unless condensed

      render turbo_stream: [
        turbo_stream.update(REVIEW_ID, partial: "review", locals: { condensed: }),
        assistant_status(t("back_office.release_notes.assistant.condensed", count: condensed.sources.size))
      ]
    end

    private
      def release_note
        Accounts::ReleaseNotes.by_token(params[:token]) or raise ActiveRecord::RecordNotFound
      end

      def skipping?
        params[:state] == "skipped"
      end

      def create_skipped
        result = Accounts::CreateReleaseNote.new.call(staff: current_player, version: params[:version], state: "skipped")
        respond(result, Accounts::CreateReleaseNote, t("back_office.release_notes.create.skipped", version: params[:version]))
      end

      def create_draft
        changes = Accounts::ReleaseVersion.parse(params[:version])&.then { Accounts::GithubReleaseChanges.for(it) }
        result = Accounts::CreateReleaseNote.new.call(staff: current_player, version: params[:version], **draft_texts(changes))
        if result.success?
          redirect_to edit_back_office_release_note_path(token: result.value!.token), notice: prefill_notice(changes), status: :see_other
        else
          redirect_refused Accounts::CreateReleaseNote, result, back_office_release_notes_path
        end
      end

      def draft_texts(changes)
        return {} unless changes

        { body_fr: changes.draft_body(:fr).truncate(Accounts::ReleaseNote::BODY_LENGTH, separator: "\n", omission: ""),
          body_en: changes.draft_body(:en).truncate(Accounts::ReleaseNote::BODY_LENGTH, separator: "\n", omission: "") }
      end

      def prefill_notice(changes)
        return t("back_office.release_notes.create.created_blank") unless changes

        t("back_office.release_notes.create.created", features: changes.features.size, fixes: changes.fixes.size, since: changes.since, head: changes.head)
      end

      def change_state(note, state)
        result = Accounts::ChangeReleaseNoteState.new.call(staff: current_player, release_note: note, state:)
        respond(result, Accounts::ChangeReleaseNoteState, t("back_office.release_notes.states_changed.#{state}", version: note.version))
      end

      def respond(result, operation, notice)
        if result.success?
          redirect_to back_office_release_notes_path, notice:, status: :see_other
        else
          redirect_refused operation, result, back_office_release_notes_path
        end
      end

      def assistant_status(message)
        turbo_stream.update(ASSISTANT_STATUS_ID, message)
      end

      def assistant_failure(code)
        render turbo_stream: assistant_status(t("back_office.release_notes.assistant.failures.#{code}")), status: :unprocessable_content
      end

      def sent_texts
        Accounts::ReleaseNote::TEXTS.index_with { params[it].to_s }
      end

      def preview_locale
        sent = params[:preview_locale].to_s
        I18n.available_locales.map(&:to_s).include?(sent) ? sent : I18n.locale.to_s
      end
  end
end
