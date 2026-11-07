module Game
  module HeldPacks
    def self.call(player, now: Time.current)
      return Reserve::NAMES.index_with(nil) if player.nil?

      season_id = Catalog::PublishedSeason.call&.id
      Reserve::NAMES.index_with { |name| held_in(player, name, season_id, now) }
    end

    def self.after(player, pack, now: Time.current)
      call(player, now:).fetch(Reserve.name_of(pack.kind))
    end

    def self.held_in(player, name, season_id, now)
      pack = Reserve.available(player.id, name, now:).first
      pack if pack && season_id && pack.season_id == season_id
    end

    private_class_method :held_in
  end
end
