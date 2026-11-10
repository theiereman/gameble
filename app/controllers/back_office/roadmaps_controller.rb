module BackOffice
  class RoadmapsController < BaseController
    PREVIEW_ID = "roadmap-preview".freeze
    TRANSLATION_STATUS_ID = "roadmap-translation-status".freeze

    rate_limit to: 30, within: 1.minute, only: :update, name: "save"
    rate_limit to: 240, within: 1.minute, only: :preview, name: "preview"
    rate_limit to: 10, within: 1.minute, only: :translate, name: "claude"

    def show
      authorize [ :back_office, :roadmap ], :show?
      @draft = Catalog::RoadmapMilestones.call
      @preview_locale = preview_locale
    end

    def update
      authorize [ :back_office, :roadmap ], :update?
      @draft = sent_draft

      result = Catalog::SaveRoadmap.new.call(draft: @draft)
      if result.success?
        redirect_to back_office_roadmap_path, notice: t(".saved"), status: :see_other
      else
        @failure = Catalog::SaveRoadmap.failure_message(result.failure)
        @row_failures = row_failures(@draft)
        @preview_locale = preview_locale
        render :show, status: :unprocessable_content
      end
    end

    def preview
      authorize [ :back_office, :roadmap ], :preview?
      render turbo_stream: turbo_stream.update(PREVIEW_ID, RoadmapPreviewComponent.new(draft: sent_draft, locale: preview_locale))
    end

    def translate
      authorize [ :back_office, :roadmap ], :translate?
      draft = sent_draft
      untranslated = untranslated_wordings(draft)
      return translation_status(t(".nothing"), status: :unprocessable_content) if untranslated.empty?

      translations = Accounts::ClaudeWriter.translate_wordings(untranslated, length: Catalog::RoadmapWording::LENGTH)
      return translation_status(t(".unavailable"), status: :unprocessable_content) unless translations

      render turbo_stream: [
        *english_wording_streams(draft, translations),
        turbo_stream.update(PREVIEW_ID, RoadmapPreviewComponent.new(draft: translated(draft, translations), locale: preview_locale)),
        translation_status(t(".translated", count: translations.size), stream: true)
      ]
    end

    private
      def untranslated_wordings(draft)
        draft.entries.select { it.wording_en.to_s.strip.empty? && it.wording_fr.to_s.strip.present? }.to_h { [ it.key, it.wording_fr ] }
      end

      def translated(draft, translations)
        english = ->(entry) { entry.with(wording_en: translations.fetch(entry.key, entry.wording_en)) }
        Catalog::RoadmapDraft.new(draft.milestones.map { english.(it).with(stories: it.stories.map(&english)) })
      end

      def english_wording_streams(draft, translations)
        draft.milestones.flat_map do |milestone|
          rows = [ [ milestone, "milestones[#{milestone.key}]", "roadmap-milestone-#{milestone.key}" ] ] +
            milestone.stories.map { [ it, "milestones[#{milestone.key}][stories][#{it.key}]", "roadmap-story-#{it.key}" ] }
          rows.filter_map do |entry, name, dom|
            next unless translations.key?(entry.key)

            turbo_stream.replace("#{dom}-wording-en", partial: "back_office/roadmaps/english_wording",
              locals: { name:, dom:, value: translations[entry.key].truncate(Catalog::RoadmapWording::LENGTH, omission: ""), failure: false })
          end
        end
      end

      def translation_status(message, stream: false, status: :ok)
        update = turbo_stream.update(TRANSLATION_STATUS_ID, message)
        stream ? update : render(turbo_stream: update, status:)
      end

      def sent_draft
        sent = params[:milestones]
        Catalog::RoadmapDraft.from_form(sent.respond_to?(:to_unsafe_h) ? sent.to_unsafe_h : nil)
      end

      def preview_locale
        sent = params[:preview_locale].to_s
        I18n.available_locales.map(&:to_s).include?(sent) ? sent : I18n.locale.to_s
      end

      def row_failures(draft)
        draft.refusals.transform_values { Catalog::SaveRoadmap.failure_message(it, limit: Catalog::RoadmapWording::LENGTH) }
      end
  end
end
