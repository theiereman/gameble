class NativeSignInsController < ApplicationController
  def show
    authorize :native_sign_in, :show?
    return redirect_to sign_in_path(origin: request.path) unless current_player

    @state = params[:state]
  end

  def create
    authorize :native_sign_in, :create?
    return redirect_to sign_in_path(origin: native_sign_in_path(state: params[:state])), status: :see_other unless current_player

    redirect_to NativeSignIn.callback_url(current_player, state: params[:state]), allow_other_host: true, status: :see_other
  end
end
