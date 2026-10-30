class ShareImagesController < ApplicationController
  include PublicRead

  CACHE_LIFETIME = 365.days

  skip_before_action :set_sentry_user, :note_presence
  # A shared cache refuses to store a response that sets a cookie.
  before_action { request.session_options[:skip] = true }

  def show
    authorize :page, :show?
    png = Catalog::ShareImageByToken.call(params[:token])
    return head :not_found if png.nil?

    expires_in CACHE_LIFETIME, public: true, immutable: true
    response.headers["X-Robots-Tag"] = "noindex"
    send_data png, type: CardShareImage::CONTENT_TYPE, disposition: :inline
  end

  private
    def pundit_user = nil
end
