module Market
  class CancellationPolicy < ApplicationPolicy
    def create? = player? && record.seller.id == player.id
  end
end
