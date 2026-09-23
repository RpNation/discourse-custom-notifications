# frozen_string_literal: true

Fabricator(:custom_notification_broadcast, class_name: "DiscourseCustomNotifications::Broadcast") do
  created_by { Fabricate(:admin) }
  request_id { SecureRandom.uuid }
  payload_digest { Digest::SHA256.hexdigest("test notification") }
  message "A new announcement is available."
  sender_user_id { Discourse.system_user.id }
  sender_username { Discourse.system_user.username }
end
