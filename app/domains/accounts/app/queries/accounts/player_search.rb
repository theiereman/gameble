module Accounts
  # The players whose accounts still exist, banned ones included, the newest
  # account first, as a relation to page. A query narrows them to the
  # players whose persona name holds it, in any case, or whose Steam id is
  # exactly it: a Steam id is a key, a name a label. The query is cleaned as
  # stored names are (Accounts::PersonaName); the wildcards of LIKE match
  # themselves.
  #
  #   Accounts::PlayerSearch.call("gabe").limit(50) # => [Accounts::Player, …]
  module PlayerSearch
    MAX_QUERY = PersonaName::LENGTH

    def self.call(query = nil)
      players = Player.where(deleted_at: nil).order(created_at: :desc, id: :desc)
      text = normalize(query)
      return players if text.empty?

      players.where("accounts_players.persona_name ILIKE :pattern OR accounts_players.steam_id = :text",
        pattern: "%#{Player.sanitize_sql_like(text)}%", text:)
    end

    # The query as searched, cleaned as a stored name is; else empty.
    def self.normalize(query)
      PersonaName.clean(query) || ""
    end
  end
end
