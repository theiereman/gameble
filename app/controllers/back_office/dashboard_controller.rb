module BackOffice
  class DashboardController < BaseController
    def show
      authorize [ :back_office, :dashboard ], :show?
      @queue_size = Accounts::ReportQueue.size
      @unclassified_tags = Catalog::UnclassifiedDraftTags.count if policy([ :back_office, :themes ]).index?
      @import_run = Steam::LatestImportRun.call if policy([ :back_office, :import_runs ]).index?
      @announcement_shown = Accounts::Announcements.any_shown? if policy([ :back_office, :announcements ]).index?
    end
  end
end
