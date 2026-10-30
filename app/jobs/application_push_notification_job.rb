class ApplicationPushNotificationJob < ActionPushNative::NotificationJob
  self.report_job_retries = true
end
