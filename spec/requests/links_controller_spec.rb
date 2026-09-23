# frozen_string_literal: true

RSpec.describe DiscourseCustomNotifications::LinksController do
  fab!(:recipient) { Fabricate(:user, approved: true) }
  fab!(:other_user) { Fabricate(:user, approved: true) }

  let(:broadcast) do
    Fabricate(:custom_notification_broadcast, link_url: "https://example.com/announcement")
  end
  let!(:notification) do
    Notification.create!(
      user: recipient,
      notification_type: Notification.types[:custom],
      data: broadcast.notification_data,
      skip_send_email: true,
    )
  end

  before do
    enable_current_plugin
    SiteSetting.discourse_custom_notifications_enabled = true
  end

  describe "#show" do
    it "redirects the recipient to the broadcast's saved URL" do
      sign_in(recipient)

      get "/custom-notifications/#{notification.id}"

      expect(response).to redirect_to(broadcast.link_url)
    end

    it "hides another member's notification and requires authentication" do
      get "/custom-notifications/#{notification.id}.json"
      expect(response.status).to eq(403)

      sign_in(other_user)
      get "/custom-notifications/#{notification.id}"

      expect(response.status).to eq(404)
      expect(response.headers["Location"]).to be_nil
    end

    it "rejects unrelated notifications and unsafe saved destinations" do
      sign_in(recipient)
      unrelated =
        Notification.create!(
          user: recipient,
          notification_type: Notification.types[:custom],
          data: { message: "another_plugin", custom_notifications_id: broadcast.id }.to_json,
          skip_send_email: true,
        )

      get "/custom-notifications/#{unrelated.id}"
      expect(response.status).to eq(404)

      broadcast.update!(link_url: "javascript:alert(1)")
      get "/custom-notifications/#{notification.id}"

      expect(response.status).to eq(404)
      expect(response.headers["Location"]).to be_nil
    end
  end
end
