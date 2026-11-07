module Game
  module LuckShare
    def shareable? = ranked_count.to_i.positive?

    def top_half? = share_from_top <= share_from_bottom

    def share_of_half = [ share_from_top, share_from_bottom ].min

    private
      def share_from_top = (rank * 100).ceildiv(ranked_count)

      def share_from_bottom = ((ranked_count - rank + 1) * 100).ceildiv(ranked_count)
  end
end
