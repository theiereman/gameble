module Accounts
  module PlayerSearch
    MAX_QUERY = PersonaName::LENGTH

    def self.call(query = nil)
      players = Player.where(deleted_at: nil).order(created_at: :desc, id: :desc)
      text = normalize(query)
      return players if text.empty?

      players.where("accounts_players.persona_name ILIKE :pattern OR accounts_players.steam_id = :text",
        pattern: "%#{Player.sanitize_sql_like(text)}%", text:)
    end

    def self.normalize(query)
      PersonaName.clean(query) || ""
    end
  end
end
