class PlayerNameComponent < ViewComponent::Base
  def initialize(player:, viewer:)
    @player = player
    @viewer = viewer
  end

  def call
    if Game::Visibility.visible?(@viewer, @player)
      link_to(name, helpers.brother_path(token: @player.token), class: "player-name player-name--linked")
    elsif @player.removed?
      tag.span(t("player_name.anonymous"), class: "player-name player-name--anonymous")
    else
      tag.span(name, class: "player-name")
    end
  end

  private
    def name = Accounts::PersonaName.clean(@player.persona_name) || t("shell.player.fallback_name")
end
