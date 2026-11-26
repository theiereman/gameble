class DeckPolicy < ApplicationPolicy
  def new? = player?
  def card_faces? = player?
  def create? = player?
  def remove_card? = player?

  def show? = owner?
  def update? = owner?
  def destroy? = owner?

  private
    def owner?
      player? && record.is_a?(Game::Deck) && record.player_id == player.id
    end
end
