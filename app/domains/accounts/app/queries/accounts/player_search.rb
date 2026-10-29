module Accounts
  module PlayerSearch
    MAX_QUERY = PersonaName::LENGTH

    def self.call(query = nil)
      players = Player.where(deleted_at: nil).order(created_at: :desc, id: :desc)
      text = normalize(query)
      return players if text.empty?

      players.where("accounts_players.persona_name ILIKE ?", "%#{Player.sanitize_sql_like(text)}%")
        .or(players.where(id: steam_identities(text)))
    end

    def self.steam_identities(text) = Identity.where(provider: "steam", uid: text).select(:player_id)
    private_class_method :steam_identities

    def self.normalize(query)
      PersonaName.clean(query) || ""
    end
  end
end
