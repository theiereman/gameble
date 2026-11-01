class CustomSetPolicy < ApplicationPolicy
  def create? = player?
  def games? = player?

  def show? = author?
  def update? = author?
  def destroy? = author?

  private
    def author?
      player? && record.is_a?(Game::CustomSet) && record.player_id == player.id
    end
end
