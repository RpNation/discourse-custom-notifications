# frozen_string_literal: true

module DiscourseCustomNotifications
  class PreviewBroadcast
    include Service::Base

    params(base_class: Payload)
    policy :administrator
    policy :plugin_enabled
    model :preview, :build_preview

    private

    def administrator(guardian:)
      guardian.is_admin?
    end

    def plugin_enabled
      SiteSetting.discourse_custom_notifications_enabled
    end

    def build_preview(params:, guardian:)
      Preview.new(payload: params, admin_id: guardian.user.id)
    end
  end
end
