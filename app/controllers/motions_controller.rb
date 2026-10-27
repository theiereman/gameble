class MotionsController < ApplicationController
  CHOICES = { "on" => true, "off" => nil }.freeze

  def create
    authorize :motion
    write_motion_cookie(CHOICES.fetch(params[:reduced].to_s, nil))
    redirect_to home_path, status: :see_other
  end
end
