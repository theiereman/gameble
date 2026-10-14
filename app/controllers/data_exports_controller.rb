class DataExportsController < ApplicationController
  RATE_LIMIT_WINDOW = 5.minutes

  rate_limit to: 1, within: RATE_LIMIT_WINDOW, only: :create,
    by: -> { current_player&.id || request.remote_ip }, with: :throttled

  def create
    authorize :data_export, :create?

    export = PlayerExport.new(current_player, locale: I18n.locale)
    file = JSON.pretty_generate(export.to_h)
    result = Accounts::NoteExport.new.call(player: current_player, at: export.exported_at)
    return export_refused(result.failure) if result.failure?

    send_data file, type: :json, filename: export.filename, disposition: :attachment
  end

  private
    def export_refused(code)
      message = Accounts::NoteExport.failure_message(code)
      respond_to do |format|
        format.json { render json: { error: { code:, message: } }, status: :unprocessable_entity }
        format.any { redirect_to settings_path, alert: message, status: :see_other }
      end
    end

    def throttled
      message = t("data_exports.create.throttled")
      respond_to do |format|
        format.json do
          response.headers["Retry-After"] = RATE_LIMIT_WINDOW.to_i.to_s
          render json: { error: { code: "throttled", message: } }, status: :too_many_requests
        end
        format.any { redirect_to settings_path, alert: message, status: :see_other }
      end
    end
end
