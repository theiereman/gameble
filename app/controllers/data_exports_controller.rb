class DataExportsController < ApplicationController
  def show
    authorize :data_export, :show?
    export = Accounts::LastExportOf.call(current_player)
    raise ActiveRecord::RecordNotFound unless export

    send_data export.file, type: :json, filename: PlayerExport.filename(export.exported_at), disposition: :attachment
  end

  def create
    authorize :data_export, :create?
    return export_refused(:export_too_soon) if current_player.next_export_at

    export = PlayerExport.new(current_player, locale: I18n.locale)
    file = JSON.pretty_generate(export.to_h)
    result = Accounts::RecordExport.new.call(player: current_player, at: export.exported_at, file:)
    return export_refused(result.failure) if result.failure?

    send_data file, type: :json, filename: export.filename, disposition: :attachment
  end

  private
    def export_refused(code)
      message = Accounts::RecordExport.failure_message(code)
      next_export_at = current_player.reload.next_export_at
      respond_to do |format|
        format.json do
          next render(json: { error: { code:, message: } }, status: :unprocessable_entity) unless next_export_at

          response.headers["Retry-After"] = (next_export_at - Time.current).ceil.to_s
          render json: { error: { code:, message:, nextExportAt: next_export_at.utc.iso8601 } }, status: :too_many_requests
        end
        format.any { redirect_to settings_path, alert: message, status: :see_other }
      end
    end
end
