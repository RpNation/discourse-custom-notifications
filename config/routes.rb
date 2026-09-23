# frozen_string_literal: true

DiscourseCustomNotifications::Engine.routes.draw do
  post "/preview" => "broadcasts#preview"
  get "/:id" => "broadcasts#show"
  post "/:id/retry" => "broadcasts#retry"
end

Discourse::Application.routes.draw do
  get "/admin/custom-notifications" => "discourse_custom_notifications/broadcasts#index"
  post "/admin/custom-notifications" => "discourse_custom_notifications/broadcasts#create"
  mount ::DiscourseCustomNotifications::Engine, at: "/admin/custom-notifications"
  get "/custom-notifications/:notification_id" => "discourse_custom_notifications/links#show"
end
