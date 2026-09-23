# frozen_string_literal: true

module DiscourseCustomNotifications
  class Preview
    include ActiveModel::Serialization

    attr_reader :recipient_count, :sample_users, :preview, :preview_token

    def initialize(payload:, admin_id:)
      scope = payload.audience.scope
      @recipient_count = scope.count
      @sample_users = scope.order(:id).limit(10).to_a
      @preview = payload.canonical.except(:filters)
      @preview_token = PreviewToken.issue(admin_id:, payload:)
    end
  end
end
