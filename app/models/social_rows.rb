module SocialRows
  LIMIT = 5

  Capped = Data.define(:rows, :hidden) do
    def empty? = rows.empty?
  end

  def self.trades(trades) = cap(trades.yours + trades.theirs)

  def self.friends(presences)
    online, offline = presences.partition(&:online?)
    return cap(online) if online.size > LIMIT

    Capped.new(rows: (online + offline).first(LIMIT), hidden: [])
  end

  def self.cap(items)
    return Capped.new(rows: items, hidden: []) if items.size <= LIMIT

    Capped.new(rows: items.first(LIMIT - 1), hidden: items.drop(LIMIT - 1))
  end
end
