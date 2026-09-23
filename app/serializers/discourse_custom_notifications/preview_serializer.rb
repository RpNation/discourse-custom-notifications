# frozen_string_literal: true

module DiscourseCustomNotifications
  class PreviewSerializer < ApplicationSerializer
    attributes :recipient_count, :sample_users, :preview, :preview_token

    def sample_users
      object.sample_users.map { |user| { id: user.id, username: user.username } }
    end
  end
end
