module BackOffice
  class ThemesController < BaseController
    PER_PAGE = 50
    SHOWN = %w[unclassified all].freeze

    TagRow = Data.define(:key, :name, :game_count, :theme_key, :dismissed) do
      def unclassified? = theme_key.nil? && !dismissed
    end

    rate_limit to: 60, within: 1.minute, only: %i[create update attach dismiss]

    def index
      authorize [ :back_office, :themes ], :index?
      @themes = Catalog::ThemeList.call
      @shown = SHOWN.include?(params[:show]) ? params[:show] : SHOWN.first
      @rescore_needed = Catalog::DraftRescoreNeeded.call
      @unclassified_count = tag_rows.count(&:unclassified?)
      rows = @shown == "all" ? tag_rows : tag_rows.select(&:unclassified?)
      @pages = [ (rows.size.fdiv(PER_PAGE)).ceil, 1 ].max
      @page = params[:page].to_s.match?(/\A[1-9]\d{0,5}\z/) ? [ params[:page].to_i, @pages ].min : 1
      @tags = rows.slice((@page - 1) * PER_PAGE, PER_PAGE) || []
    end

    def create
      authorize [ :back_office, :themes ], :create?

      result = Catalog::CreateTheme.new.call(tag_key: params[:tag_key], name_en: params[:name_en], name_fr: params[:name_fr])
      respond(result, Catalog::CreateTheme, t(".created"))
    end

    def update
      authorize [ :back_office, :themes ], :update?

      result = Catalog::RenameTheme.new.call(theme: theme_of(params[:token]), name_en: params[:name_en], name_fr: params[:name_fr])
      respond(result, Catalog::RenameTheme, t(".updated"))
    end

    def attach
      authorize [ :back_office, :themes ], :attach?
      return alert_back(t(".theme_required")) if params[:theme].blank?

      result = Catalog::AttachTag.new.call(tag_key: params[:tag_key], theme: theme_of(params[:theme]))
      respond(result, Catalog::AttachTag, t(".attached"))
    end

    def dismiss
      authorize [ :back_office, :themes ], :dismiss?

      result = Catalog::DismissTags.new.call(tag_keys: params.permit(tag_keys: [])[:tag_keys])
      respond(result, Catalog::DismissTags, t(".dismissed", count: result.success? ? result.value!.size : 0))
    end

    private
      def theme_of(token)
        Catalog::ThemeByToken.call(token) or raise ActiveRecord::RecordNotFound
      end

      def alert_back(alert)
        redirect_to back_office_themes_path(params.permit(:show, :page).to_h.symbolize_keys), alert:, status: :see_other
      end

      def respond(result, operation, notice)
        destination = back_office_themes_path(params.permit(:show, :page).to_h.symbolize_keys)
        if result.success?
          redirect_to destination, notice:, status: :see_other
        else
          redirect_refused operation, result, destination
        end
      end

      def tag_rows
        @tag_rows ||= begin
          classification = Catalog::Themes.classification
          Steam::DraftTags.call.map do |tag|
            TagRow.new(key: tag.key, name: tag.name, game_count: tag.game_count, theme_key: classification.theme_by_tag[tag.key],
              dismissed: classification.dismissed.include?(tag.key))
          end
        end
      end
  end
end
