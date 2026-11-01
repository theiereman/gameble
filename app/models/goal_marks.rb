class GoalMarks
  def self.filter_value(target)
    target.custom? ? target.custom_set_token : "#{target.kind}:#{target.key}"
  end

  attr_reader :needs

  def initialize(needs)
    @needs = needs.sort_by(&:position)
    @by_card = @needs.each_with_object({}) do |need, index|
      need.card_ids.each { (index[it] ||= []) << need }
    end
  end

  NONE = new([])

  def any? = needs.any?

  def targets = needs.map(&:target)

  def without(target)
    return self if target.nil?

    GoalMarks.new(needs.reject { it.goal_id == target.goal_id })
  end

  def goals_for(card_id) = @by_card.fetch(card_id, [])

  def numbers_for(card_id) = goals_for(card_id).map(&:position)

  def chosen(values)
    asked = Array(values)
    needs.select { asked.include?(GoalMarks.filter_value(it)) }
  end

  def card_ids_of(chosen) = chosen.flat_map(&:card_ids).uniq
end
