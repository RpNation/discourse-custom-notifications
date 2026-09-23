# frozen_string_literal: true

module DiscourseCustomNotifications
  class QueueBroadcast
    include Service::Base

    params(base_class: Payload) do
      attribute :preview_token, :string
      attribute :request_id, :string
      validates :preview_token, presence: true
      validates :request_id,
                format: {
                  with: /\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/i,
                }
    end
    policy :administrator
    policy :plugin_enabled
    policy :confirmed_preview
    model :broadcast, :queue_broadcast
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

    def confirmed_preview(params:, guardian:)
      PreviewToken.valid?(params.preview_token, admin_id: guardian.user.id, payload: params)
    end

    def queue_broadcast(params:, guardian:)
      Broadcast.queue!(actor: guardian.user, payload: params, request_id: params.request_id)
    end

    def unfinished?(broadcast:)
      broadcast.unfinished?
    end

    def schedule_delivery(broadcast:)
      Jobs.enqueue(:deliver_custom_notifications, broadcast_id: broadcast.id)
    end
  end
end
