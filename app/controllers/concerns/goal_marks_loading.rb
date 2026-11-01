module GoalMarksLoading
  extend ActiveSupport::Concern

  private
    def goal_marks
      @goal_marks ||= current_player ? GoalMarks.new(Game::GoalNeeds.call(current_player)) : GoalMarks::NONE
    end
end
