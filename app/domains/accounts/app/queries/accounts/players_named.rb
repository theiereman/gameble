module Accounts
  module PlayersNamed
    def self.call(text, excluding:, limit:)
      pattern = Player.sanitize_sql_like(text.downcase)
      Player.in_good_standing.where.not(id: excluding).where.not(visibility: "private")
        .where("accounts_players.persona_name ILIKE ?", "%#{pattern}%")
        .order(Arel.sql(Player.sanitize_sql_array([ "lower(accounts_players.persona_name) = ? DESC", text.downcase ])))
        .order(Arel.sql(Player.sanitize_sql_array([ "lower(accounts_players.persona_name) LIKE ? DESC", "#{pattern}%" ])))
        .order(:persona_name, :id)
        .limit(limit).to_a
    end
  end
end
