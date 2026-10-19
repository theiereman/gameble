module BackOffice
  # The stories under a roadmap milestone, administrators only: added,
  # edited, moved and deleted, each back on the milestone's page.
  class RoadmapStoriesController < BaseController
    include RoadmapEntries

    rate_limit to: 60, within: 1.minute, only: %i[create update move destroy]

    def new
      authorize [ :back_office, :roadmap ], :new?
      @milestone = roadmap_milestone(params[:roadmap_milestone_token])
      @entry = Entry.new(wording_fr: nil, wording_en: nil, status: "to_come", shown: true)
    end

    def create
      authorize [ :back_office, :roadmap ], :create?
      @milestone = roadmap_milestone(params[:roadmap_milestone_token])

      result = Catalog::CreateRoadmapStory.new.call(milestone: @milestone, **entry_params)
      if result.success?
        redirect_to edit_back_office_roadmap_milestone_path(@milestone), notice: t(".created"), status: :see_other
      else
        @entry = sent_entry
        @failure = refusal_message(Catalog::CreateRoadmapStory, result.failure)
        render :new, status: :unprocessable_content
      end
    end

    def edit
      authorize [ :back_office, :roadmap ], :edit?
      @story = roadmap_story(params[:token])
      @entry = entry_of(@story)
    end

    def update
      authorize [ :back_office, :roadmap ], :update?
      @story = roadmap_story(params[:token])

      result = Catalog::UpdateRoadmapStory.new.call(story: @story, **entry_params)
      if result.success?
        redirect_to edit_back_office_roadmap_milestone_path(@story.milestone), notice: t(".updated"), status: :see_other
      else
        @entry = sent_entry
        @failure = refusal_message(Catalog::UpdateRoadmapStory, result.failure)
        render :edit, status: :unprocessable_content
      end
    end

    def move
      authorize [ :back_office, :roadmap ], :move?
      story = roadmap_story(params[:token])

      result = Catalog::MoveRoadmapStory.new.call(story:, direction: params[:direction])
      back_to_milestone(story, result, notice: t(".moved"), operation: Catalog::MoveRoadmapStory)
    end

    def destroy
      authorize [ :back_office, :roadmap ], :destroy?
      story = roadmap_story(params[:token])

      result = Catalog::DeleteRoadmapStory.new.call(story:)
      back_to_milestone(story, result, notice: t(".deleted"), operation: Catalog::DeleteRoadmapStory)
    end

    private
      def back_to_milestone(story, result, notice:, operation:)
        flash_message = result.success? ? { notice: } : { alert: refusal_message(operation, result.failure) }
        redirect_to edit_back_office_roadmap_milestone_path(story.milestone), **flash_message, status: :see_other
      end
  end
end
