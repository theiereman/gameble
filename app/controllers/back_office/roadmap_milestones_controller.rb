module BackOffice
  # The landing's roadmap milestones, administrators only: every milestone in
  # its order, and one milestone's wording, status and visibility with its
  # stories. Staff never create or delete a milestone.
  class RoadmapMilestonesController < BaseController
    include RoadmapEntries

    rate_limit to: 60, within: 1.minute, only: %i[update move]

    def index
      authorize [ :back_office, :roadmap ], :index?
      @milestones = Catalog::RoadmapMilestones.call
    end

    def edit
      authorize [ :back_office, :roadmap ], :edit?
      @milestone = roadmap_milestone(params[:token])
      @entry = entry_of(@milestone)
      @stories = Catalog::RoadmapStories.call(@milestone)
    end

    def update
      authorize [ :back_office, :roadmap ], :update?
      @milestone = roadmap_milestone(params[:token])

      result = Catalog::UpdateRoadmapMilestone.new.call(milestone: @milestone, **entry_params)
      if result.success?
        redirect_to back_office_roadmap_milestones_path, notice: t(".updated"), status: :see_other
      else
        @entry = sent_entry
        @failure = refusal_message(Catalog::UpdateRoadmapMilestone, result.failure)
        @stories = Catalog::RoadmapStories.call(@milestone)
        render :edit, status: :unprocessable_content
      end
    end

    def move
      authorize [ :back_office, :roadmap ], :move?

      result = Catalog::MoveRoadmapMilestone.new.call(milestone: roadmap_milestone(params[:token]), direction: params[:direction])
      if result.success?
        redirect_to back_office_roadmap_milestones_path, notice: t(".moved"), status: :see_other
      else
        redirect_to back_office_roadmap_milestones_path, alert: refusal_message(Catalog::MoveRoadmapMilestone, result.failure), status: :see_other
      end
    end
  end
end
