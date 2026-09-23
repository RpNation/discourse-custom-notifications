# frozen_string_literal: true

module DiscourseCustomNotifications
  class BroadcastsController < ::Admin::AdminController
    requires_plugin PLUGIN_NAME

    def index
      render json: {
               broadcasts:
                 ActiveModel::ArraySerializer.new(
                   Broadcast.includes(:created_by).order(id: :desc).limit(50),
                   each_serializer: BroadcastSerializer,
                   root: false,
                 ),
               groups:
                 RecipientQuery
                   .selectable_groups
                   .pluck(:id, :name)
                   .map { |id, name| { id:, name: } },
               current_username: current_user.username,
             }
    end

    def show
      broadcast = Broadcast.find(params[:id])
      render json: { broadcast: BroadcastSerializer.new(broadcast, root: false) }
    end

    def preview
      PreviewBroadcast.call(service_params) do
        on_success { |preview:| render json: PreviewSerializer.new(preview, root: false) }
        on_failed_contract do |contract|
          render json: { errors: contract.errors.full_messages }, status: :unprocessable_entity
        end
        on_failed_policy(:administrator) { raise Discourse::InvalidAccess }
        on_failed_policy(:plugin_enabled) { raise Discourse::NotFound }
        on_failure { render json: failed_json, status: :unprocessable_entity }
      end
    end

    def create
      QueueBroadcast.call(service_params) do
        on_success do |broadcast:|
          render json: { broadcast: BroadcastSerializer.new(broadcast, root: false) }
        end
        on_failed_contract do |contract|
          render json: { errors: contract.errors.full_messages }, status: :unprocessable_entity
        end
        on_failed_policy(:administrator) { raise Discourse::InvalidAccess }
        on_failed_policy(:plugin_enabled) { raise Discourse::NotFound }
        on_failed_policy(:confirmed_preview) do
          render json: {
                   errors: [I18n.t("discourse_custom_notifications.invalid_preview")],
                 },
                 status: :unprocessable_entity
        end
        on_failure { render json: failed_json, status: :unprocessable_entity }
      end
    end

    def retry
      RetryBroadcast.call(service_params.deep_merge(params: { broadcast_id: params[:id] })) do
        on_success do |broadcast:|
          render json: { broadcast: BroadcastSerializer.new(broadcast, root: false) }
        end
        on_failed_contract do |contract|
          render json: { errors: contract.errors.full_messages }, status: :unprocessable_entity
        end
        on_failed_policy(:administrator) { raise Discourse::InvalidAccess }
        on_failed_policy(:plugin_enabled) { raise Discourse::NotFound }
        on_model_not_found(:broadcast) { raise Discourse::NotFound }
        on_failure { render json: failed_json, status: :unprocessable_entity }
      end
    end
  end
end
