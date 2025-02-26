# frozen_string_literal: true

BulletmarkRepairerTestApp::Application.routes.draw do
  resources :multiple_lines, only: [:index]
  resource :single_line, only: [:show]
  resources :not_in_blocks, only: %i[index show new]
  resources :in_nested_blocks, only: [:index]
  resources :previous_lines, only: [:index]
  resources :multiple_actions, only: %i[index show]
  resources :n_plus_one_in_views, only: [:index]
  resources :n_plus_one_in_views_multiple_methods, only: %i[index show]
  resources :partial_views, only: [:index]
  resources :multiple_base_classes, only: [:index]
  resources :nested_includes, only: [:index]
  resources :nested_includes_in_views, only: [:index]
  resources :another_name_associations, only: [:index]
  resources :nested_and_another_name_includes, only: [:index]
  resources :avoid_includes, only: [:index]
end
