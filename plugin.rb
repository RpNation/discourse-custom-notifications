# frozen_string_literal: true

# name: discourse-custom-notifications
# about: Send targeted, audited in-app notifications from the admin interface
# version: 0.0.1
# authors: RpNation
# required_version: 2026.3.0

enabled_site_setting :discourse_custom_notifications_enabled

register_asset "stylesheets/common/custom-notifications.scss", :admin
register_svg_icon "bullhorn"
add_admin_route "discourse_custom_notifications.title",
                "discourse-custom-notifications",
                use_new_show_route: true

module ::DiscourseCustomNotifications
  PLUGIN_NAME = "discourse-custom-notifications"
end

require_relative "lib/discourse_custom_notifications/engine"

Discourse::Application.routes.append do
  get "/admin/plugins/discourse-custom-notifications/notifications(/*path)" =>
        "admin/plugins#index",
      :constraints => AdminConstraint.new
end
