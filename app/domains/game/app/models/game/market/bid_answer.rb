module Game
  module Market
    # What a placed bid left: the branch it took and the amounts the bidding screen names.
    BidAnswer = Data.define(:branch, :equal_maximum, :price, :maximum, :minimum, :listing)
  end
end
