# frozen_string_literal: true

RSpec.describe DiscourseCustomNotifications::Payload do
  before { enable_current_plugin }

  describe ".valid_url?" do
    it "accepts site paths and HTTP URLs while rejecting executable or ambiguous destinations" do
      valid_urls = [
        "",
        "/t/announcement/123?source=notice#post_2",
        "https://example.com/news",
        "http://example.com",
      ]
      invalid_urls = [
        "javascript:alert(1)",
        "data:text/html,<script>alert(1)</script>",
        "//example.com/news",
        "/\\example.com/news",
        "https://user:password@example.com",
        "https://example.com/\nnews",
        "https://example.com/with space",
        "mailto:member@example.com",
      ]

      aggregate_failures do
        valid_urls.each { |url| expect(described_class.valid_url?(url)).to eq(true), url }
        invalid_urls.each { |url| expect(described_class.valid_url?(url)).to eq(false), url }
      end
    end
  end

  describe "#valid?" do
    it "rejects messages that fit the text limit but overflow the encoded notification payload" do
      payload = described_class.new(message: "\\" * 500, filters: {})

      expect(payload).not_to be_valid
      expect(payload.errors[:message]).to include(
        I18n.t("discourse_custom_notifications.payload_too_long"),
      )
    end
  end
end
