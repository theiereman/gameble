class DataExportsController < ApplicationController
  RATE_LIMIT_WINDOW = 5.minutes

  rate_limit to: 1, within: RATE_LIMIT_WINDOW, only: :create,
    by: -> { current_player&.id || request.remote_ip }, with: :throttled

  def create
    authorize :data_export, :create?

    export = PlayerExport.new(current_player, locale: I18n.locale)
    send_data JSON.pretty_generate(export.to_h), type: :json, filename: export.filename, disposition: :attachment
  end

  private
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
