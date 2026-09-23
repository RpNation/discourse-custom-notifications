# frozen_string_literal: true

module Jobs
  class DeliverCustomNotifications < ::Jobs::Base
    def execute(args)
      broadcast = DiscourseCustomNotifications::Broadcast.find_by(id: args[:broadcast_id])
      return unless broadcast

      unless SiteSetting.discourse_custom_notifications_enabled
        broadcast.update!(status: "paused") if broadcast.unfinished?
        return
      end

      broadcast.update!(status: "processing", last_error: "") if broadcast.unfinished?
      deliveries =
        broadcast.deliveries.where(status: "pending").order(:id).limit(broadcast.class::BATCH_SIZE)
      deliveries.each do |delivery|
        break unless SiteSetting.discourse_custom_notifications_enabled
        delivery.deliver!
      end

      unless SiteSetting.discourse_custom_notifications_enabled
        broadcast.update!(status: "paused")
        return
      end

      if broadcast.unfinished?
        Jobs.enqueue(:deliver_custom_notifications, broadcast_id: broadcast.id)
      else
        broadcast.update!(status: "completed", last_error: "")
      end
    rescue => error
      broadcast&.update_columns(status: "failed", last_error: error.message.to_s.truncate(1000))
      raise
    end
  end
end
