class SignInsController < ApplicationController
  include PublicRead
  include PlayerLanding

  def show
    authorize :sign_in, :show?

    @origin = origin_param
    @mode = request.path_parameters[:mode] == "callback" ? "callback" : "start"
    @callback_url = sign_in_callback_url(origin: @origin)
    redirect_to(landing_path_for(current_player, @origin)) if current_player
  end

  private

  def origin_param
    origin = params[:origin]
    origin if origin.is_a?(String) && SessionsController::ORIGIN_PATH.match?(origin.split(/[?#]/, 2).first)
  end
end
