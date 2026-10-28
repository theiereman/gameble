module PersonalizationRefusal
  extend ActiveSupport::Concern

  private
    def personalization_refused(message, code:)
      respond_to do |format|
        format.turbo_stream { render turbo_stream: turbo_stream.append("toasts", ToastComponent.new(message:, tone: :alert)), status: :unprocessable_content }
        format.html { redirect_to personalization_path, alert: message, status: :see_other }
        format.json { render json: { error: { code:, message: } }, status: :unprocessable_content }
      end
    end
end
