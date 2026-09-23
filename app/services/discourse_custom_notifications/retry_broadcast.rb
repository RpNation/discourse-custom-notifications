# frozen_string_literal: true

module DiscourseCustomNotifications
  class RetryBroadcast
    include Service::Base

    params do
      attribute :broadcast_id, :integer
      validates :broadcast_id, presence: true, numericality: { greater_than: 0 }
    end

    policy :administrator
    policy :plugin_enabled
    model :broadcast
    step :resume_delivery
    only_if :unfinished? do
      step :schedule_delivery
    end

    private

    def administrator(guardian:)
      guardian.is_admin?
    end

    def plugin_enabled
      SiteSetting.discourse_custom_notifications_enabled
    end

    def fetch_broadcast(params:)
      Broadcast.find_by(id: params.broadcast_id)
    end

    def resume_delivery(broadcast:)
      broadcast.retry_delivery!
    end

    def unfinished?(broadcast:)
      broadcast.unfinished?
    end

    def schedule_delivery(broadcast:)
      Jobs.enqueue(:deliver_custom_notifications, broadcast_id: broadcast.id)
    end
  end
end
