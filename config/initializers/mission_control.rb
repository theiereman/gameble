# Mission Control Jobs (R7), mounted at /back-office/jobs for administrators
# only. Its controllers inherit BackOffice::JobsBaseController, which takes
# the Pundit decision and refuses through ApplicationController's single
# refusal path; the engine's own HTTP basic auth is off.
MissionControl::Jobs.base_controller_class = "BackOffice::JobsBaseController"
MissionControl::Jobs.http_basic_auth_enabled = false
