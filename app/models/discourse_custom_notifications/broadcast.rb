# frozen_string_literal: true

module DiscourseCustomNotifications
  class Broadcast < ActiveRecord::Base
    self.table_name = "discourse_custom_notification_broadcasts"

    BATCH_SIZE = 100
    NOTIFICATION_MARKER = "discourse_custom_notifications.notice"

    belongs_to :created_by, class_name: "User"
    has_many :deliveries,
             class_name: "DiscourseCustomNotifications::Delivery",
             dependent: :delete_all

    def self.notification_data(id:, message:, link_url:, link_title:, sender_username:)
      {
        message: NOTIFICATION_MARKER,
        topic_title: message,
        display_username: sender_username,
        custom_notifications_id: id,
        has_link: link_url.present?,
        link_title:,
      }
    end

    def self.queue!(actor:, payload:, request_id:)
      actor.with_lock do
        existing = find_by(created_by: actor, request_id:)
        if existing
          unless existing.payload_digest == payload.digest
            raise Discourse::InvalidParameters,
                  I18n.t("discourse_custom_notifications.request_conflict")
          end
          next existing
        end

        broadcast =
          create!(
            created_by: actor,
            request_id:,
            payload_digest: payload.digest,
            message: payload.message,
            link_url: payload.link_url,
            link_title: payload.link_title,
            sender_user_id: payload.sender.id,
            sender_username: payload.sender.username,
          )

        # The audience is frozen in one SQL statement, without loading a site's
        # entire user list into the web process or re-evaluating it on retries.
        users_sql = payload.audience.scope.reselect("users.id").to_sql
        count = DB.exec(<<~SQL, broadcast_id: broadcast.id)
          INSERT INTO discourse_custom_notification_deliveries
            (broadcast_id, user_id, status, created_at, updated_at)
          SELECT :broadcast_id, recipients.id, 'pending', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP
          FROM (#{users_sql}) recipients
        SQL
        broadcast.update!(total_count: count, status: count.zero? ? "completed" : "queued")
        StaffActionLogger.new(actor).log_custom(
          "custom_notification_queued",
          broadcast_id: broadcast.id,
          recipient_count: count,
          sender: broadcast.sender_username,
        )
        broadcast
      end
    end

    def notification_data
      self.class.notification_data(id:, message:, link_url:, link_title:, sender_username:).to_json
    end

    def unfinished?
      deliveries.where(status: "pending").exists?
    end

    def retry_delivery!
      with_lock { update!(status: unfinished? ? "queued" : "completed", last_error: "") }
    end
  end
end

# == Schema Information
#
# Table name: discourse_custom_notification_broadcasts
#
#  id              :bigint           not null, primary key
#  last_error      :text             default(""), not null
#  link_title      :string(100)      default(""), not null
#  link_url        :string(2048)     default(""), not null
#  message         :string(500)      not null
#  payload_digest  :string           not null
#  sender_username :string           not null
#  sent_count      :integer          default(0), not null
#  skipped_count   :integer          default(0), not null
#  status          :string           default("queued"), not null
#  total_count     :integer          default(0), not null
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  created_by_id   :integer          not null
#  request_id      :uuid             not null
#  sender_user_id  :integer          not null
#
# Indexes
#
#  idx_custom_notification_request  (created_by_id,request_id) UNIQUE
#
