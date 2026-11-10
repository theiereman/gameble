class FriendSearchesController < ApplicationController
  rate_limit to: 60, within: 1.minute, only: :show, name: "friend-search",
    by: -> { current_player&.id || request.remote_ip },
    with: -> { head :too_many_requests }

  def show
    authorize :friend, :search?
    @query = Accounts::PersonaName.clean(params[:q]).to_s
    @candidates = Game::InviteCandidates.call(current_player, @query)
  end
end
