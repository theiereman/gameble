require "dry/operation/extensions/active_record"

# Base class of every operation. An operation wraps its writes and its
# event in `transaction`, and returns Success(value) or Failure(:code).
#
#   class Game::OpenPack < Game::Operation
#     def call(player:)
#       player = step require_player(player)
#       transaction do
#         pack = step next_pack(player) # Failure(:no_pack_available) rolls back
#         step publish(Game::PackOpened.new(data: { player_id: player.id, pack_id: pack.id }),
#           stream_name: Game::Operation.stream_name(player.id)) # "Game::Player$<id>"
#         pack
#       end
#     end
#   end
#
# A Failure inside `transaction` rolls back the rows and the event together.
#
# An operation calls another operation of its pack only through `step`
# (`step Game::DrawPack.new.call(...)`). The inner `transaction` joins the
# outer one, so an inner Failure handled without `step` would keep the inner
# rows and event; through `step` it halts the outer flow and rolls back the
# whole transaction.
class ApplicationOperation < Dry::Operation
  include Dry::Operation::Extensions::ActiveRecord

  # The locale key of a failure code: errors.<pack>.<code>, where <pack> is
  # the underscored first segment of the class name.
  def self.failure_key(code)
    "errors.#{name.split("::").first.underscore}.#{code}"
  end

  # The translated message of a failure code in the current locale.
  def self.failure_message(code)
    I18n.t(failure_key(code))
  end

  private

  # Publishes an event to the app's event store. Call it inside
  # `transaction` so the event commits or rolls back with the rows. Events
  # carry identifiers only.
  def publish(event, stream_name:)
    event_store.publish(event, stream_name: stream_name)
    Success(event)
  end

  def event_store
    Rails.configuration.event_store
  end
end
