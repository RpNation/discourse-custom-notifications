# frozen_string_literal: true

module DiscourseCustomNotifications
  class LinksController < ::ApplicationController
    requires_plugin PLUGIN_NAME
    requires_login
    skip_before_action :check_xhr, :preload_json, only: :show

    def show
      notification = current_user.notifications.find_by(id: params[:notification_id])
      unless notification && notification.notification_type == Notification.types[:custom] &&
               notification.data_hash[:message] == Broadcast::NOTIFICATION_MARKER
        raise Discourse::NotFound
      end

      broadcast = Broadcast.find_by(id: notification.data_hash[:custom_notifications_id])
      unless broadcast && broadcast.link_url.present? && Payload.valid_url?(broadcast.link_url)
        raise Discourse::NotFound
      end

      redirect_to broadcast.link_url, allow_other_host: true
    end
  end
end
