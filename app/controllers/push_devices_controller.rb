class PushDevicesController < ApplicationController
  SESSION_KEY = :push_device

  def create
    authorize :push_device, :create?
    result = Accounts::RegisterPushDevice.new.call(player: current_player, platform: params[:platform], token: params[:token], locale: I18n.locale.to_s)
    return head :unprocessable_entity if result.failure?

    session[SESSION_KEY] = result.value!.token
    head :no_content
  end
end
