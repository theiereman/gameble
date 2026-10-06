# Marking the collection seen (AD-26, AD-14). A visitor is refused and asked
# to sign in.
#
#   authorize :collection_seen, :create?
class CollectionSeenPolicy < ApplicationPolicy
  # Any signed-in player marks their own collection; there is nothing else
  # to mark.
  def create? = player?
end
