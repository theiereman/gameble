class NativeSessionsController < ApplicationController
  include OpensPlayerSession

  # The app posts from outside any web view, so it holds no authenticity token: the ticket and its state stand in for it.
  skip_forgery_protection only: :create

  def create
    authorize :native_session, :create?
    player = NativeSignIn.player_for(params[:ticket], state: params[:state])
    return head :unauthorized if player.nil? || player.removed?

    open_session_for(player)
    head :no_content
  end
end
