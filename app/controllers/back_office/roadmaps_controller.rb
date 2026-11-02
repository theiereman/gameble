module BackOffice
  class RoadmapsController < BaseController
    PREVIEW_ID = "roadmap-preview".freeze

    rate_limit to: 30, within: 1.minute, only: :update, name: "save"
    rate_limit to: 240, within: 1.minute, only: :preview, name: "preview"

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

    private
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
