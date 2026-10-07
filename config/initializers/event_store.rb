# One Rails Event Store client for the whole app (AD-10). Operations publish
# through ApplicationOperation#publish, inside their own transaction.
#
# Handlers subscribed here run synchronously, inside the publishing
# transaction: a handler that raises rolls the operation back.
Rails.configuration.to_prepare do
  event_store = RailsEventStore::JSONClient.new

  # A new player's bank is filled within the sign-up (AD-7).
  event_store.subscribe(Game::Handlers::PlayerRegistered, to: [ Accounts::PlayerRegistered ])
  # Players left without a bank get one when a season is published.
  event_store.subscribe(Game::Handlers::SeasonPublished, to: [ Catalog::SeasonPublished ])

  # Every opening counts toward the weekly goal (AD-10).
  event_store.subscribe(Game::Handlers::PackOpened, to: [ Game::PackOpened ])
  # The notable pulls of an opening go to the activity feed (AD-10, AD-13).
  event_store.subscribe(Game::Handlers::PackOpenedFeed, to: [ Game::PackOpened ])
  # A player's own actions are their latest activity, read by their friends'
  # presence (AD-24).
  event_store.subscribe(Game::Handlers::PlayerActivity, to: Game::Handlers::PlayerActivity::EVENTS.keys)

  Rails.configuration.event_store = event_store
end
