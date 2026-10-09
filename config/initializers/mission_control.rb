# Mission Control Jobs, mounted at /back-office/jobs for administrators
# only. Its controllers inherit BackOffice::JobsBaseController, which hides
# the engine from whoever is not staff, takes the Pundit decision and
# refuses staff through ApplicationController's single refusal path; the
# engine's own HTTP basic auth is off.
MissionControl::Jobs.base_controller_class = "BackOffice::JobsBaseController"
MissionControl::Jobs.http_basic_auth_enabled = false
