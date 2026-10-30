class PersonalizationsController < ApplicationController
  def show
    authorize :personalization, :show?
    redirect_to brother_path(token: current_player.token), status: :moved_permanently
  end
end
