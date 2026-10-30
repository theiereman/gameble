module Steam
  module OwnedGames
    extend Dry::Monads[:result]

    def self.call(steam_id:, api: WebApi.new)
      appids = api.get_owned_games(steamid: steam_id)
      return Failure(:library_private) if appids.nil?

      Success(Catalog::PublishedCardIds.call(source_keys: appids.map { |appid| CardMapping.source_key(appid) }))
    rescue WebApi::Unavailable
      Failure(:steam_unavailable)
    end
  end
end
