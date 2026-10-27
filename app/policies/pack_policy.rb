class PackPolicy < ApplicationPolicy
  def create? = player?

  def show?
    player? && record.is_a?(Game::Pack) && record.player_id == player.id && record.opened?
  end
end
