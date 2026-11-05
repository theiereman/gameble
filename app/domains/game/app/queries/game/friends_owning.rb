module Game
  module FriendsOwning
    Owners = Data.define(:same, :other) do
      def none? = same.empty? && other.empty?
    end
    Owner = Data.define(:player, :copies, :editions)

    NONE = Owners.new(same: [], other: [])

    SQL = <<~SQL.squish.freeze
      SELECT game_holdings.player_id, game_holdings.card_season_id, catalog_card_seasons.rarity, catalog_seasons.number, game_holdings.quantity
        FROM game_holdings
        JOIN catalog_card_seasons ON catalog_card_seasons.id = game_holdings.card_season_id
        JOIN catalog_seasons ON catalog_seasons.id = catalog_card_seasons.season_id
       WHERE game_holdings.player_id IN (:player_ids) AND game_holdings.quantity > 0
         AND catalog_card_seasons.card_id = :card_id AND catalog_card_seasons.rarity IS NOT NULL
       ORDER BY catalog_card_seasons.rarity DESC, catalog_seasons.number
    SQL

    def self.call(viewer, card_id:, card_season_id:)
      friends = FriendsOf.call(viewer).select { Visibility.open_to_friends?(it) }
      return NONE if friends.empty?

      holdings = holdings_by_friend(friends.map(&:id), card_id)
      owners = friends.filter_map { |friend| owner(friend, holdings[friend.id], card_season_id) }
      same, other = owners.partition(&:first)
      Owners.new(same: sorted(same), other: sorted(other))
    end

    def self.holdings_by_friend(player_ids, card_id)
      rows = Holding.connection.select_rows(Holding.sanitize_sql_array([ SQL, { player_ids:, card_id: } ]), "Game::FriendsOwning")
      rows.group_by { it.first.to_i }.transform_values do |held|
        held.map { |_, held_id, rarity, season_number, quantity| [ held_id.to_i, Catalog::Rarity::TIERS.fetch(rarity.to_i).to_s, season_number.to_i, quantity.to_i ] }
      end
    end

    def self.owner(friend, held, card_season_id)
      return if held.blank?

      viewed = held.find { |held_id, *| held_id == card_season_id }
      editions = held.map { |_, *edition| edition }
      copies = viewed ? viewed.last : editions.sum(&:last)
      [ viewed.present?, Owner.new(player: friend, copies:, editions:) ]
    end

    def self.sorted(owners)
      owners.map(&:last).sort_by { [ -it.copies, Accounts::PersonaName.clean(it.player.persona_name).to_s.downcase, it.player.token ] }
    end

    private_class_method :holdings_by_friend, :owner, :sorted
  end
end
