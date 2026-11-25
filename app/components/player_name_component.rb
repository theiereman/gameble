class PlayerNameComponent < ViewComponent::Base
  def initialize(player:, viewer:, linked: true, friends: nil, supporters: nil)
    @player = player
    @viewer = viewer
    @linked = linked
    @friends = friends
    @supporters = supporters
  end

  def call
    if @player.nil?
      tag.span(t("player_name.archives"), class: "player-name")
    elsif @player.removed?
      tag.span(t("player_name.anonymous"), class: "player-name player-name--anonymous")
    elsif supporter?
      tag.span(safe_join([ shown_name, helpers.supporter_badge_tag(compact: true) ], " "), class: "player-name-group")
    else
      shown_name
    end
  end

  private
    def shown_name
      if @linked && Game::Visibility.visible?(@viewer, @player, friends: @friends)
        link_to(name, helpers.brother_path(token: @player.token), class: "player-name player-name--linked")
      else
        tag.span(name, class: "player-name")
      end
    end

    def supporter? = @supporters&.include?(@player.id) && clean_name.present?

    def clean_name = Accounts::PersonaName.clean(@player.persona_name)

    def name = clean_name || t("shell.player.fallback_name")
end
