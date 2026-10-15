# Closing a new player's welcome panel from the hub, for good and on every
# device (Accounts::CloseWelcome). From the hub it answers in Turbo Stream,
# which removes the panel; without JavaScript it redirects to the hub.
class WelcomesController < ApplicationController
  # DELETE /:locale/welcome
  def destroy
    authorize :welcome, :destroy?

    Accounts::CloseWelcome.new.call(player_id: current_player.id)

    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to home_path, status: :see_other }
    end
  end
end
