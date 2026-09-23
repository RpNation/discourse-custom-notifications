# frozen_string_literal: true

RSpec.describe DiscourseCustomNotifications::BroadcastsController do
  fab!(:admin)
  fab!(:recipient) { Fabricate(:user, approved: true) }

  let(:notification_params) do
    {
      message: "An announcement for your group.",
      link_url: "/latest",
      link_title: "Read the announcement",
      sender_username: admin.username,
      filters: {
        username: recipient.username,
        username_exact: true,
      },
    }
  end

  before do
    enable_current_plugin
    SiteSetting.discourse_custom_notifications_enabled = true
    Jobs.run_later!
  end

  def preview_token(params = notification_params)
    post "/admin/custom-notifications/preview.json", params: params
    response.parsed_body.fetch("preview_token")
  end

  describe "#index" do
    it "denies anonymous users, members, and moderators" do
      get "/admin/custom-notifications.json"
      expect(response.status).to eq(403)

      [recipient, Fabricate(:moderator)].each do |user|
        sign_in(user)
        get "/admin/custom-notifications.json"
        expect(response.status).to eq(403)
      end
    end

    it "provides administrators with history and selectable groups" do
      sign_in(admin)
      group = Fabricate(:group)
      broadcast = Fabricate(:custom_notification_broadcast, created_by: admin)

      get "/admin/custom-notifications.json"

      expect(response.status).to eq(200)
      expect(response.parsed_body["broadcasts"].map { |row| row["id"] }).to eq([broadcast.id])
      expect(response.parsed_body["current_username"]).to eq(admin.username)
      group_ids = response.parsed_body["groups"].map { |row| row["id"] }
      expect(group_ids).to include(group.id)
      expect(
        group_ids & Group::AUTO_GROUPS.values_at(:everyone, :anonymous_users, :logged_in_users),
      ).to be_empty
    end
  end

  describe "#preview" do
    before { sign_in(admin) }

    it "returns the matched audience and escaped-text source without creating a broadcast" do
      params = notification_params.merge(message: '<img src=x onerror="alert(1)"> & announcement')

      expect do post "/admin/custom-notifications/preview.json", params: params end.not_to change(
        DiscourseCustomNotifications::Broadcast,
        :count,
      )

      expect(response.status).to eq(200)
      expect(response.parsed_body["recipient_count"]).to eq(1)
      expect(response.parsed_body["sample_users"]).to eq(
        [{ "id" => recipient.id, "username" => recipient.username }],
      )
      expect(response.parsed_body.dig("preview", "message")).to eq(params[:message])
      expect(response.parsed_body["preview_token"]).to be_present
      expect(response.body).not_to include(recipient.email)
    end

    it "fails closed on unknown filters and rejects preview access when disabled" do
      post "/admin/custom-notifications/preview.json",
           params: notification_params.merge(filters: { misspelled_group_ids: [1] })

      expect(response.status).to eq(422)
      expect(response.parsed_body["preview_token"]).to be_nil

      SiteSetting.discourse_custom_notifications_enabled = false
      post "/admin/custom-notifications/preview.json", params: notification_params

      expect(response.status).to eq(404)
    end
  end

  describe "#create" do
    before { sign_in(admin) }

    it "queues the confirmed audience once when the same request is submitted twice" do
      params =
        notification_params.merge(preview_token: preview_token, request_id: SecureRandom.uuid)

      expect do
        2.times do
          post "/admin/custom-notifications.json", params: params
          expect(response.status).to eq(200)
        end
      end.to change(DiscourseCustomNotifications::Broadcast, :count).by(1)

      broadcast =
        DiscourseCustomNotifications::Broadcast.find(response.parsed_body.dig("broadcast", "id"))
      expect(broadcast).to have_attributes(
        created_by_id: admin.id,
        status: "queued",
        total_count: 1,
      )
      expect(broadcast.deliveries.pluck(:user_id)).to eq([recipient.id])
      expect(Jobs::DeliverCustomNotifications.jobs.last["args"].first["broadcast_id"]).to eq(
        broadcast.id,
      )
      audit_entries =
        UserHistory.where(
          acting_user_id: admin.id,
          action: UserHistory.actions[:custom_staff],
          custom_type: "custom_notification_queued",
        )
      expect(audit_entries.count).to eq(1)
      expect(audit_entries.first.admin_only).to eq(true)
      expect(audit_entries.first.details).not_to include(recipient.email)
    end

    it "denies a member even when they supply an administrator's preview token" do
      params =
        notification_params.merge(preview_token: preview_token, request_id: SecureRandom.uuid)
      sign_in(recipient)

      expect do post "/admin/custom-notifications.json", params: params end.not_to change(
        DiscourseCustomNotifications::Broadcast,
        :count,
      )

      expect(response.status).to eq(403)
    end

    it "rejects missing and tampered preview tokens" do
      token = preview_token

      [nil, "#{token}tampered"].each do |invalid_token|
        expect do
          post "/admin/custom-notifications.json",
               params:
                 notification_params.merge(
                   preview_token: invalid_token,
                   request_id: SecureRandom.uuid,
                 )
        end.not_to change(DiscourseCustomNotifications::Broadcast, :count)

        expect(response.status).to eq(422)
      end
    end

    it "binds the preview to its message and audience" do
      token = preview_token
      changes = [{ message: "A changed message." }, { filters: {} }]

      changes.each do |change|
        expect do
          post "/admin/custom-notifications.json",
               params:
                 notification_params.merge(change).merge(
                   preview_token: token,
                   request_id: SecureRandom.uuid,
                 )
        end.not_to change(DiscourseCustomNotifications::Broadcast, :count)

        expect(response.status).to eq(422)
      end
    end

    it "binds the preview to the administrator who requested it" do
      params =
        notification_params.merge(preview_token: preview_token, request_id: SecureRandom.uuid)
      sign_in(Fabricate(:admin))

      expect do post "/admin/custom-notifications.json", params: params end.not_to change(
        DiscourseCustomNotifications::Broadcast,
        :count,
      )

      expect(response.status).to eq(422)
    end

    it "expires preview authorization after fifteen minutes" do
      params =
        notification_params.merge(preview_token: preview_token, request_id: SecureRandom.uuid)
      freeze_time 16.minutes.from_now

      expect do post "/admin/custom-notifications.json", params: params end.not_to change(
        DiscourseCustomNotifications::Broadcast,
        :count,
      )

      expect(response.status).to eq(422)
    end
  end

  describe "#show" do
    it "keeps a broadcast's history private to administrators" do
      broadcast = Fabricate(:custom_notification_broadcast, created_by: admin)
      sign_in(recipient)

      get "/admin/custom-notifications/#{broadcast.id}.json"
      expect(response.status).to eq(403)
      expect(response.body).not_to include(broadcast.message)

      sign_in(admin)
      get "/admin/custom-notifications/#{broadcast.id}.json"

      expect(response.status).to eq(200)
      expect(response.parsed_body["broadcast"]).to include(
        "id" => broadcast.id,
        "message" => broadcast.message,
        "created_by_username" => admin.username,
      )
    end
  end

  describe "#retry" do
    it "lets administrators resume failed deliveries without granting members that access" do
      broadcast =
        Fabricate(
          :custom_notification_broadcast,
          created_by: admin,
          status: "failed",
          total_count: 1,
        )
      broadcast.deliveries.create!(user_id: recipient.id)
      sign_in(recipient)

      post "/admin/custom-notifications/#{broadcast.id}/retry.json"
      expect(response.status).to eq(403)
      expect(broadcast.reload.status).to eq("failed")

      sign_in(admin)
      post "/admin/custom-notifications/#{broadcast.id}/retry.json"

      expect(response.status).to eq(200)
      expect(response.parsed_body.dig("broadcast", "status")).to eq("queued")
      expect(Jobs::DeliverCustomNotifications.jobs.last["args"].first["broadcast_id"]).to eq(
        broadcast.id,
      )
    end
  end
end
