# frozen_string_literal: true

RSpec.describe DiscourseCustomNotifications::RecipientQuery do
  before { enable_current_plugin }

  describe "#scope" do
    it "includes eligible members and excludes accounts that cannot receive a broadcast" do
      eligible = Fabricate(:user, approved: true)
      expired_suspension = Fabricate(:user, approved: true, suspended_till: 1.day.ago)
      Fabricate(:inactive_user, approved: true)
      Fabricate(:user, approved: false)
      Fabricate(:user, approved: true, staged: true)
      Fabricate(:user, approved: true, suspended_till: 1.day.from_now)
      Fabricate(:anonymous, approved: true)

      expect(described_class.new({}).scope).to contain_exactly(eligible, expired_suspension)
    end

    it "matches usernames and all email addresses case insensitively without duplicate recipients" do
      recipient =
        Fabricate(
          :user,
          approved: true,
          username: "CampaignMember",
          email: "first@campaign.example",
        )
      Fabricate(:secondary_email, user: recipient, email: "second@campaign.example")
      Fabricate(:user, approved: true, username: "OtherMember", email: "other@campaign.example")

      expect(
        described_class.new(username: "CAMPAIGN", email: "@CAMPAIGN.EXAMPLE").scope,
      ).to contain_exactly(recipient)
      expect(
        described_class.new(username: "CAMPAIGNMEMBER", username_exact: true).scope,
      ).to contain_exactly(recipient)
      expect(
        described_class.new(email: "SECOND@CAMPAIGN.EXAMPLE", email_exact: true).scope,
      ).to contain_exactly(recipient)
      expect(described_class.new(username: "CAMPAIGN", username_exact: true).scope).to be_empty
    end

    it "treats SQL pattern characters in substring filters literally" do
      recipient = Fabricate(:user, approved: true, username: "campaign_member")
      Fabricate(:user, approved: true, username: "campaignXmember")

      expect(described_class.new(username: "campaign_member").scope).to contain_exactly(recipient)
      expect(described_class.new(username: "%").scope).to be_empty
    end

    it "combines primary group and inclusion filters while giving exclusions precedence" do
      primary_group = Fabricate(:group)
      included_group = Fabricate(:group)
      excluded_group = Fabricate(:group)
      recipient = Fabricate(:user, approved: true, primary_group: primary_group)
      excluded = Fabricate(:user, approved: true, primary_group: primary_group)
      other_primary = Fabricate(:user, approved: true)
      primary_group.add(recipient)
      included_group.add(recipient)
      included_group.add(excluded)
      included_group.add(other_primary)
      excluded_group.add(excluded)

      filters = {
        primary_group_id: primary_group.id,
        include_group_ids: [primary_group.id, included_group.id],
        exclude_group_ids: [excluded_group.id],
      }

      expect(described_class.new(filters).scope).to contain_exactly(recipient)
    end
  end

  describe ".new" do
    it "rejects malformed filters, missing groups, and implicit groups instead of widening the audience" do
      invalid_filters = [
        nil,
        { unknown_filter: "value" },
        { username: ["member"] },
        { email_exact: "yes" },
        { include_group_ids: "1,2" },
        { exclude_group_ids: ["1 OR 1=1"] },
        { primary_group_id: Group.maximum(:id).to_i + 1 },
      ]
      Group::AUTO_GROUPS
        .values_at(:everyone, :anonymous_users, :logged_in_users)
        .each do |group_id|
          invalid_filters << { include_group_ids: [group_id] }
          invalid_filters << { exclude_group_ids: [group_id] }
          invalid_filters << { primary_group_id: group_id }
        end

      aggregate_failures do
        invalid_filters.each do |filters|
          expect { described_class.new(filters) }.to raise_error(Discourse::InvalidParameters)
        end
      end
    end
  end
end
