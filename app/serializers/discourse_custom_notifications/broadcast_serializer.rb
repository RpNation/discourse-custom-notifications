# frozen_string_literal: true

module DiscourseCustomNotifications
  class BroadcastSerializer < ApplicationSerializer
    attributes :id,
               :message,
               :link_url,
               :link_title,
               :sender_username,
               :created_at,
               :status,
               :total_count,
               :sent_count,
               :skipped_count,
               :last_error,
               :created_by_username

    def created_by_username
      object.created_by&.username
    end
  end
end
