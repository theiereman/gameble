class DeckPolicy < ApplicationPolicy
  def new? = player?
  def create? = player?

  def show? = owner?
  def update? = owner?
  def destroy? = owner?

  private
    def owner?
      player? && record.is_a?(Game::Deck) && record.player_id == player.id
    end
end
