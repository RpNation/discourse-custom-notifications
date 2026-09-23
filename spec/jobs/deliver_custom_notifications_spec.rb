# frozen_string_literal: true

RSpec.describe Jobs::DeliverCustomNotifications do
  fab!(:admin)
  fab!(:recipient) { Fabricate(:user, approved: true) }
  fab!(:other_recipient) { Fabricate(:user, approved: true) }

  let(:broadcast) { Fabricate(:custom_notification_broadcast, created_by: admin, total_count: 2) }

  before do
    enable_current_plugin
    SiteSetting.discourse_custom_notifications_enabled = true
    Jobs.run_later!
    broadcast.deliveries.create!(user_id: recipient.id)
    broadcast.deliveries.create!(user_id: other_recipient.id)
  end

  describe "#execute" do
    it "creates one notification per recipient across repeated executions" do
      expect do 2.times { described_class.new.execute(broadcast_id: broadcast.id) } end.to change(
        Notification,
        :count,
      ).by(2)

      expect(broadcast.reload).to have_attributes(
        status: "completed",
        sent_count: 2,
        skipped_count: 0,
      )
      notifications = Notification.where(id: broadcast.deliveries.pluck(:notification_id))
      expect(notifications.pluck(:user_id)).to contain_exactly(recipient.id, other_recipient.id)
      expect(notifications.map(&:data_hash)).to all(
        eq(
          "message" => DiscourseCustomNotifications::Broadcast::NOTIFICATION_MARKER,
          "topic_title" => broadcast.message,
          "custom_notifications_id" => broadcast.id,
          "display_username" => broadcast.sender_username,
          "has_link" => false,
          "link_title" => "",
        ),
      )
      expect(broadcast.deliveries.pluck(:status)).to eq(%w[sent sent])
    end

    it "skips recipients who become suspended or are deleted after being queued" do
      recipient.update!(suspended_till: 1.day.from_now)
      other_recipient.destroy!

      expect do described_class.new.execute(broadcast_id: broadcast.id) end.not_to change(
        Notification,
        :count,
      )

      expect(broadcast.reload).to have_attributes(
        status: "completed",
        sent_count: 0,
        skipped_count: 2,
      )
      expect(broadcast.deliveries.pluck(:status)).to eq(%w[skipped skipped])
    end

    it "pauses pending work while the plugin is disabled" do
      SiteSetting.discourse_custom_notifications_enabled = false

      expect do described_class.new.execute(broadcast_id: broadcast.id) end.not_to change(
        Notification,
        :count,
      )

      expect(broadcast.reload).to have_attributes(status: "paused", sent_count: 0)
      expect(broadcast.deliveries.pluck(:status)).to eq(%w[pending pending])
    end

    it "processes a bounded batch and queues the remaining recipients" do
      stub_const(DiscourseCustomNotifications::Broadcast, :BATCH_SIZE, 1) do
        expect do described_class.new.execute(broadcast_id: broadcast.id) end.to change {
          described_class.jobs.size
        }.by(1)

        expect(broadcast.reload.sent_count).to eq(1)
        expect(broadcast.deliveries.pluck(:status)).to contain_exactly("sent", "pending")

        described_class.new.execute(broadcast_id: broadcast.id)

        expect(broadcast.reload).to have_attributes(status: "completed", sent_count: 2)
      end
    end

    it "rolls back the notification when recording delivery fails and retries without duplicates" do
      DB.exec(<<~SQL)
        ALTER TABLE discourse_custom_notification_deliveries
        ADD CONSTRAINT custom_notification_spec_reject_sent CHECK (status <> 'sent')
      SQL

      expect do
        expect do described_class.new.execute(broadcast_id: broadcast.id) end.to raise_error(
          ActiveRecord::StatementInvalid,
        )
      end.not_to change(Notification, :count)

      expect(broadcast.reload).to have_attributes(status: "failed", sent_count: 0)
      expect(broadcast.deliveries.pluck(:status)).to eq(%w[pending pending])

      DB.exec(
        "ALTER TABLE discourse_custom_notification_deliveries DROP CONSTRAINT custom_notification_spec_reject_sent",
      )
      described_class.new.execute(broadcast_id: broadcast.id)

      expect(broadcast.reload).to have_attributes(status: "completed", sent_count: 2)
      expect(broadcast.deliveries.pluck(:notification_id).uniq.size).to eq(2)
    ensure
      DB.exec(
        "ALTER TABLE discourse_custom_notification_deliveries DROP CONSTRAINT IF EXISTS custom_notification_spec_reject_sent",
      )
    end
  end
end
