# frozen_string_literal: true

module DiscourseCustomNotifications
  class RecipientQuery
    FILTER_KEYS = %w[
      username
      username_exact
      email
      email_exact
      primary_group_id
      include_group_ids
      exclude_group_ids
    ].freeze
    IMPLICIT_GROUP_IDS =
      Group::AUTO_GROUPS.values_at(:everyone, :anonymous_users, :logged_in_users).freeze

    attr_reader :filters

    def self.eligible_users
      User.real.activated.approved.not_staged.not_suspended
    end

    def self.selectable_groups
      Group.where.not(id: IMPLICIT_GROUP_IDS).order(:name)
    end

    def initialize(filters)
      @filters = normalize(filters)
    end

    def scope
      users = self.class.eligible_users

      %w[username email].each do |field|
        next if filters[field].blank?
        column = field == "username" ? "users.username_lower" : "LOWER(user_emails.email)"
        value = filters[field].downcase
        users = users.joins(:user_emails) if field == "email"
        users =
          if filters["#{field}_exact"]
            users.where("#{column} = ?", value)
          else
            users.where("#{column} LIKE ?", "%#{ActiveRecord::Base.sanitize_sql_like(value)}%")
          end
      end

      users = users.where(primary_group_id: filters["primary_group_id"]) if filters[
        "primary_group_id"
      ]
      if filters["include_group_ids"].present?
        users =
          users.where(id: GroupUser.where(group_id: filters["include_group_ids"]).select(:user_id))
      end
      if filters["exclude_group_ids"].present?
        users =
          users.where.not(
            id: GroupUser.where(group_id: filters["exclude_group_ids"]).select(:user_id),
          )
      end
      users.distinct
    end

    private

    def normalize(input)
      invalid! unless input.is_a?(Hash)
      values = input.stringify_keys
      invalid! if (values.keys - FILTER_KEYS).any?

      result = {}
      %w[username email].each do |field|
        value = values.fetch(field, "")
        invalid! unless value.is_a?(String) && value.length <= 320
        result[field] = value.strip
        exact = values.fetch("#{field}_exact", false)
        invalid! if [true, false, "true", "false"].exclude?(exact)
        result["#{field}_exact"] = exact == true || exact == "true"
      end

      primary = values["primary_group_id"]
      result["primary_group_id"] = primary.nil? || primary == "" ? nil : group_id(primary)
      %w[include_group_ids exclude_group_ids].each do |field|
        ids = values.fetch(field, [])
        invalid! unless ids.is_a?(Array) && ids.length <= 100
        result[field] = ids.map { |value| group_id(value) }.uniq.sort
      end

      ids = [
        result["primary_group_id"],
        *result["include_group_ids"],
        *result["exclude_group_ids"],
      ].compact.uniq
      invalid! unless self.class.selectable_groups.where(id: ids).count == ids.length
      result
    end

    def group_id(value)
      invalid! unless value.is_a?(Integer) || value.is_a?(String)
      invalid! unless value.to_s.match?(/\A[1-9]\d{0,9}\z/)
      invalid! if value.to_i > 2_147_483_647
      value.to_i
    end

    def invalid!
      raise Discourse::InvalidParameters, I18n.t("discourse_custom_notifications.invalid_filters")
    end
  end
end
