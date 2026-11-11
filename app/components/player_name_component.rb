class PlayerNameComponent < ViewComponent::Base
  def initialize(player:, viewer:, linked: true)
    @player = player
    @viewer = viewer
    @linked = linked
  end

  def call
    if @player.removed?
      tag.span(t("player_name.anonymous"), class: "player-name player-name--anonymous")
    elsif @linked && Game::Visibility.visible?(@viewer, @player)
      link_to(name, helpers.brother_path(token: @player.token), class: "player-name player-name--linked")
    else
      tag.span(name, class: "player-name")
    end
  end

  private
    def name = Accounts::PersonaName.clean(@player.persona_name) || t("shell.player.fallback_name")
end
