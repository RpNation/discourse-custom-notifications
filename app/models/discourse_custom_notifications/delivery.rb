# frozen_string_literal: true

module DiscourseCustomNotifications
  class Delivery < ActiveRecord::Base
    self.table_name = "discourse_custom_notification_deliveries"

    belongs_to :broadcast, class_name: "DiscourseCustomNotifications::Broadcast"

    def deliver!
      with_lock(requires_new: true) do
        next unless status == "pending"

        user = RecipientQuery.eligible_users.find_by(id: user_id)
        if user
          notification =
            Notification.create!(
              user:,
              notification_type: Notification.types[:custom],
              data: broadcast.notification_data,
              skip_send_email: true,
            )
          update!(status: "sent", notification_id: notification.id)
          Broadcast.where(id: broadcast_id).update_all("sent_count = sent_count + 1")
        else
          update!(status: "skipped")
          Broadcast.where(id: broadcast_id).update_all("skipped_count = skipped_count + 1")
        end
      end
    end
  end
end

# == Schema Information
#
# Table name: discourse_custom_notification_deliveries
#
#  id              :bigint           not null, primary key
#  status          :string           default("pending"), not null
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  broadcast_id    :bigint           not null
#  notification_id :bigint
#  user_id         :integer          not null
#
# Indexes
#
#  idx_custom_notification_pending    (broadcast_id,id) WHERE ((status)::text = 'pending'::text)
#  idx_custom_notification_recipient  (broadcast_id,user_id) UNIQUE
#
