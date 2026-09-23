# frozen_string_literal: true

DiscourseCustomNotifications::Engine.routes.draw do
  get "/examples" => "examples#index"
  # define routes here
end

Discourse::Application.routes.draw { mount ::DiscourseCustomNotifications::Engine, at: "discourse-custom-notifications" }
