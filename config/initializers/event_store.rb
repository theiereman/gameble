# One Rails Event Store client for the whole app (AD-10). Operations publish
# through ApplicationOperation#publish, inside their own transaction.
#
# Handlers subscribed here run synchronously, inside the publishing
# transaction: a handler that raises rolls the operation back.
Rails.configuration.to_prepare do
  # The gem's default request metadata also records the client's IP address on every event.
  event_store = RailsEventStore::JSONClient.new(request_metadata: ->(env) { { request_id: ActionDispatch::Request.new(env).uuid } })

  # A new player's bank is filled within the sign-up (AD-7).
  event_store.subscribe(Game::Handlers::PlayerRegistered, to: [ Accounts::PlayerRegistered ])
  # Handlers run in subscription order: PlayerStream reads the ties the PlayerDeleted and PlayerBanned handlers drop,
  # and the trade partners before the VisibilityChanged handler cancels the trades.
  event_store.subscribe(PlayerStream, to: PlayerStream::CUT_OFF_EVENTS + PlayerStream::PRIVACY_EVENTS)
  # A deleted account's game is released within the deletion (AD-14).
  event_store.subscribe(Game::Handlers::PlayerDeleted, to: [ Accounts::PlayerDeleted ])
  event_store.subscribe(Game::Handlers::PlayerBanned, to: [ Accounts::PlayerBanned ])
  event_store.subscribe(Game::Handlers::VisibilityChanged, to: [ Accounts::VisibilityChanged ])
  # Players left without a bank get one when a season is published.
  event_store.subscribe(Game::Handlers::SeasonPublished, to: [ Catalog::SeasonPublished ])

  # Every opening counts toward the weekly goal (AD-10).
  event_store.subscribe(Game::Handlers::PackOpened, to: [ Game::PackOpened ])
  # The notable pulls of an opening go to the activity feed (AD-10, AD-13).
  event_store.subscribe(Game::Handlers::PackOpenedFeed, to: [ Game::PackOpened ])
  event_store.subscribe(Game::Handlers::CardRepostedFeed, to: [ Game::CardReposted ])
  event_store.subscribe(Game::Handlers::TradeAccepted, to: [ Game::TradeAccepted ])
  event_store.subscribe(LiveStream, to: LiveStream::EVENTS)
  event_store.subscribe(Game::Handlers::PlayerActivity, to: Game::Handlers::PlayerActivity::EVENTS.keys)

  event_store.subscribe(PlayerStream, to: PlayerStream::EVENTS)

  Rails.configuration.event_store = event_store
end
