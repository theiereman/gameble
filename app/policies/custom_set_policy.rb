class CustomSetPolicy < ApplicationPolicy
  def new? = player?
  def create? = player?
  def picker? = player?

  def show? = author?
  def edit? = author?
  def update? = author?
  def destroy? = author?

  private
    def author?
      player? && record.is_a?(Game::CustomSet) && record.player_id == player.id
    end
end
