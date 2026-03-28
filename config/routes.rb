# config/routes.rb

Rails.application.routes.draw do
  get "user_training_progresses/index"
  get "user_training_progresses/show"
  get "user_training_progresses/create"
  get "user_training_progresses/update"
  get "user_training_assignments/index"
  get "user_training_assignments/show"
  get "user_training_assignments/create"
  get "user_training_assignments/destroy"
  get "training_questions/index"
  get "training_questions/show"
  get "training_questions/new"
  get "training_questions/create"
  get "training_questions/edit"
  get "training_questions/update"
  get "training_questions/destroy"
  get "trainings/index"
  get "trainings/show"
  get "trainings/new"
  get "trainings/create"
  get "trainings/edit"
  get "trainings/update"
  get "trainings/destroy"
  resources :user_details do
    collection do
      get :get_activities
      post :bulk_create
      get :get_user_detail
      post :submit_achievements
      get :export
      post :import
      get :download_template
      post :bulk_upload
      get :quarterly_edit_all
      patch :update_quarterly_achievements
      get :test_sms
      get :test_email
      get :clear_sms_tracking
      get :view_sms_logs
      get :export_excel
      get :export_department_activity
    end
  end

  resources :departments do
    member do
      get :edit_data
      patch :update_employee_activity_data
      post :delete_user_activities  # Changed from delete to post for JSON data
      delete :delete_user_from_department  # New route for deleting user from specific department
    end
    collection do
      post :import
      get :export
      delete :delete_employee_activities
      get :activity_list
    end
    resources :activities, except: [ :show ]
  end

  # Custom route for updating employee activities
  post "departments/update_employee_activities", to: "departments#update_employee_activities"

  # Custom route for deleting individual activities
  delete "departments/delete_activity/:activity_id", to: "departments#delete_activity"

  # Test route to verify routing is working
  get "departments/test_route", to: "departments#test_route"
  # This makes the employee list the home page.

  resources :employee_details do
    collection do
      get :export_xlsx
      get :export_quarterly_xlsx  # Export quarterly L1 L2 data
      post :import
      get :download_template
      get "l1"
      get "l2"  # ➤ this is your sidebar L1 view
      get "l3"  # ➤ this is your sidebar L3 view
    end
     member do
      patch :approve
      patch :return
      patch :l2_approve  # L2 approve
      patch :l2_return
      patch :l3_approve  # L3 approve
      patch :l3_return   # L3 return
      patch :edit_l1     # L1 edit for L2/L3 returned scenarios
      patch :edit_l2     # L2 edit for L3 returned scenarios
      get :show_l2  # This maps to /employee_details/:id/show_l2
      get :show_l3  # This maps to /employee_details/:id/show_l3
      get :get_status   # DYNAMIC: AJAX endpoint for real-time status updates
    end
  end

  devise_for :users, controllers: {
    sessions: "users/sessions",
    registrations: "users/registrations",
    passwords: "users/passwords"
  }
  # Add a specific route for the dashboard
  root to: "home#dashboard"  # 👈 now root goes to dashboard
  get "dashboard", to: "home#dashboard"
  post "update_dashboard_status", to: "home#update_dashboard_status"

  # Submitted View Data route
  get "submitted_view_data", to: "home#submitted_view_data"
  get "submitted_view_data_test", to: "home#submitted_view_data_test"
  get "quarterly_details", to: "home#quarterly_details"

  # Settings routes
  get "settings", to: "settings#show"
  patch "settings/profile", to: "settings#update_profile"
  patch "settings/password", to: "settings#change_password"

  # Keep your other routes
  devise_scope :user do
    delete "/users/sign_out", to: "devise/sessions#destroy"
  end

  resources :user_training_assignments, only: [ :index, :show, :edit, :update ], param: :employee_detail_id do
    collection do
      get :export_xlsx
    end
  end

  resources :trainings do
    member do
      post :start
      post :finish
      patch :toggle_status
      get  :preview
      post :start_training
      post :update_progress
      post :complete_training
      get  :certificate
      get  :assessment
      post :submit_assessment
    end
    collection do
      get "monthly_certificate/:year/:month", to: "trainings#monthly_certificate", as: :monthly_certificate
      get :download_assessment_template
    end
  end
end
