# frozen_string_literal: true

module DiscourseCustomNotifications
  class PreviewToken
    PURPOSE = "discourse-custom-notifications-preview"

    def self.issue(admin_id:, payload:)
      verifier.generate(
        { admin_id:, digest: payload.digest },
        expires_in: 15.minutes,
        purpose: PURPOSE,
      )
    end

    def self.valid?(token, admin_id:, payload:)
      data = verifier.verified(token, purpose: PURPOSE)
      return false unless data.is_a?(Hash)
      data = data.with_indifferent_access
      data[:admin_id] == admin_id && data[:digest] == payload.digest
    rescue ArgumentError
      false
    end

    def self.verifier
      Rails.application.message_verifier(PURPOSE)
    end
  end
end
