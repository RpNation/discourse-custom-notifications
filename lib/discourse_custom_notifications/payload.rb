# frozen_string_literal: true

module DiscourseCustomNotifications
  class Payload < Service::ContractBase
    attribute :message, :string
    attribute :link_url, :string, default: ""
    attribute :link_title, :string, default: ""
    attribute :sender_username, :string, default: ""
    attribute :filters, default: -> { {} }

    before_validation :normalize_text
    validates :message, presence: true, length: { maximum: 500 }
    validates :link_url, length: { maximum: 2048 }
    validates :link_title, length: { maximum: 100 }
    validate :valid_audience
    validate :valid_sender
    validate :valid_link
    validate :encoded_payload_fits

    def audience
      @audience ||= RecipientQuery.new(filters)
    end

    def sender
      @sender ||=
        if sender_username.blank?
          Discourse.system_user
        else
          User.real.find_by(username_lower: sender_username.downcase)
        end
    end

    def canonical
      {
        message:,
        link_url:,
        link_title:,
        sender_username: sender.username,
        filters: audience.filters,
      }
    end

    def digest
      Digest::SHA256.hexdigest(canonical.to_json)
    end

    def self.valid_url?(value)
      return true if value.blank?
      return false if value.match?(/[\x00-\x20\x7f\\]/) || value.start_with?("//")
      uri = URI.parse(value)
      if value.start_with?("/")
        uri.scheme.nil? && uri.host.nil?
      else
        %w[http https].include?(uri.scheme) && uri.host.present? && uri.userinfo.nil?
      end
    rescue URI::InvalidURIError
      false
    end

    private

    def normalize_text
      self.message = message.to_s.strip
      self.link_url = link_url.to_s.strip
      self.link_title = link_title.to_s.strip
      self.sender_username = sender_username.to_s.strip
    end

    def valid_audience
      audience
    rescue Discourse::InvalidParameters
      errors.add(:filters, I18n.t("discourse_custom_notifications.invalid_filters"))
    end

    def valid_sender
      unless sender
        errors.add(:sender_username, I18n.t("discourse_custom_notifications.invalid_sender"))
      end
    end

    def valid_link
      unless self.class.valid_url?(link_url)
        errors.add(:link_url, I18n.t("discourse_custom_notifications.invalid_link"))
      end
    end

    def encoded_payload_fits
      return unless sender
      data =
        Broadcast.notification_data(
          id: 9_223_372_036_854_775_807,
          message:,
          link_url:,
          link_title:,
          sender_username: sender.username,
        )
      if data.to_json.length > 1000
        errors.add(:message, I18n.t("discourse_custom_notifications.payload_too_long"))
      end
    end
  end
end
