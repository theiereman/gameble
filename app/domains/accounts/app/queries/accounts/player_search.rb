module Accounts
  module PlayerSearch
    MAX_QUERY = PersonaName::LENGTH

    def self.call(query = nil)
      players = Player.where(deleted_at: nil).order(created_at: :desc, id: :desc)
      text = normalize(query)
      return players if text.empty?

      players.where("accounts_players.persona_name ILIKE :pattern OR accounts_players.id IN (#{steam_identities})",
        pattern: "%#{Player.sanitize_sql_like(text)}%", text:)
    end

    def self.steam_identities
      "SELECT player_id FROM accounts_identities WHERE provider = 'steam' AND uid = :text"
    end
    private_class_method :steam_identities

    def self.normalize(query)
      PersonaName.clean(query) || ""
    end
  end
end
