class WelcomesController < ApplicationController
  def destroy
    authorize :welcome, :destroy?

    Accounts::CloseWelcome.new.call(player_id: current_player.id)

    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to home_path, status: :see_other }
    end
  end
end
