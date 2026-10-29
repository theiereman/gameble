class SteamLinksController < ApplicationController
  def create
    authorize :steam_link, :create?

    nonce = SecureRandom.urlsafe_base64(24)
    session[SessionsController::STEAM_LINK] = nonce
    # 307 makes the browser post the same form, its token and origin included, to OmniAuth's request phase;
    # OmniAuth carries the query into Steam's signed return_to, which binds the return to this request.
    redirect_to "/auth/steam?#{{ link: nonce }.to_query}", status: :temporary_redirect
  end
end
