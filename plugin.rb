# frozen_string_literal: true

# name: discourse-custom-notifications
# about: TODO
# meta_topic_id: TODO
# version: 0.0.1
# authors: Discourse
# url: TODO
# required_version: 2.7.0

enabled_site_setting :discourse_custom_notifications_enabled

module ::DiscourseCustomNotifications
  PLUGIN_NAME = "discourse-custom-notifications"
end

require_relative "lib/discourse_custom_notifications/engine"

after_initialize do
  # Code which should run after Rails has finished booting
end
