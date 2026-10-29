class SignInsController < ApplicationController
  include PublicRead

  def show
    authorize :sign_in, :show?

    @origin = origin_param
    @mode = request.path_parameters[:mode] == "callback" ? "callback" : "start"
    @callback_url = sign_in_callback_url(origin: @origin)
    redirect_to(@origin || home_path) if current_player
  end

  private

  def origin_param
    origin = params[:origin]
    origin if origin.is_a?(String) && SessionsController::ORIGIN_PATH.match?(origin.split(/[?#]/, 2).first)
  end
end
