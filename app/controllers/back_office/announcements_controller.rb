module BackOffice
  class AnnouncementsController < BaseController
    rate_limit to: 30, within: 1.minute, only: %i[create update publish withdraw]

    def index
      authorize [ :back_office, :announcements ], :index?
      @announcements = Accounts::Announcements.newest_first
      @dismissal_counts = Accounts::Announcements.dismissal_counts(@announcements)
    end

    def create
      authorize [ :back_office, :announcements ], :create?

      result = Accounts::CreateAnnouncement.new.call(staff: current_player, message_fr: params[:message_fr], message_en: params[:message_en],
        shown: params[:shown] == "1")
      respond(result, Accounts::CreateAnnouncement, t(".created"))
    end

    def update
      authorize [ :back_office, :announcements ], :update?

      result = Accounts::EditAnnouncement.new.call(staff: current_player, announcement:, message_fr: params[:message_fr], message_en: params[:message_en])
      respond(result, Accounts::EditAnnouncement, t(".updated"))
    end

    def publish
      authorize [ :back_office, :announcements ], :publish?

      result = Accounts::ShowAnnouncement.new.call(staff: current_player, announcement:)
      respond(result, Accounts::ShowAnnouncement, t(".published"))
    end

    def withdraw
      authorize [ :back_office, :announcements ], :withdraw?

      result = Accounts::HideAnnouncement.new.call(staff: current_player, announcement:)
      respond(result, Accounts::HideAnnouncement, t(".withdrawn"))
    end

    private
      def announcement
        Accounts::Announcements.by_token(params[:token]) or raise ActiveRecord::RecordNotFound
      end

      def respond(result, operation, notice)
        if result.success?
          redirect_to back_office_announcements_path, notice:, status: :see_other
        else
          redirect_refused operation, result, back_office_announcements_path
        end
      end
  end
end
