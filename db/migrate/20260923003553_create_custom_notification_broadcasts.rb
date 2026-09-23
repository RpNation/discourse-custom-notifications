# frozen_string_literal: true

class CreateCustomNotificationBroadcasts < ActiveRecord::Migration[8.0]
  def change
    create_table :discourse_custom_notification_broadcasts do |table|
      table.integer :created_by_id, null: false
      table.uuid :request_id, null: false
      table.string :payload_digest, null: false
      table.string :message, limit: 500, null: false
      table.string :link_url, limit: 2048, null: false, default: ""
      table.string :link_title, limit: 100, null: false, default: ""
      table.integer :sender_user_id, null: false
      table.string :sender_username, null: false
      table.string :status, null: false, default: "queued"
      table.integer :total_count, null: false, default: 0
      table.integer :sent_count, null: false, default: 0
      table.integer :skipped_count, null: false, default: 0
      table.text :last_error, null: false, default: ""
      table.timestamps
    end

    add_index :discourse_custom_notification_broadcasts,
              %i[created_by_id request_id],
              unique: true,
              name: "idx_custom_notification_request"

    create_table :discourse_custom_notification_deliveries do |table|
      table.bigint :broadcast_id, null: false
      table.integer :user_id, null: false
      table.bigint :notification_id
      table.string :status, null: false, default: "pending"
      table.timestamps
    end

    add_index :discourse_custom_notification_deliveries,
              %i[broadcast_id user_id],
              unique: true,
              name: "idx_custom_notification_recipient"
    add_index :discourse_custom_notification_deliveries,
              %i[broadcast_id id],
              where: "status = 'pending'",
              name: "idx_custom_notification_pending"
  end
end
