# config/routes.rb

Rails.application.routes.draw do
resources :user_details do
  collection do
    get :get_activities
    post :bulk_create
  end
end

  resources :departments do
    member do
      get :edit_data
    end
    resources :activities, except: [:show]
  end
  # This makes the employee list the home page.

resources :employee_details do
    collection do
      get :export_xlsx
      post :import
      get 'l1'
      get 'l2'  # ➤ this is your sidebar L1 view
    end
     member do
      patch :approve
      patch :return
      patch :l2_approve  # L2 approve
      patch :l2_return  
      get :show_l2  # This maps to /employee_details/:id/show_l2
    end
  end
    devise_for :users
  
  # Add a specific route for the dashboard
  root "employee_details#index"

  # Keep your other routes
  devise_scope :user do
    delete '/users/sign_out', to: 'devise/sessions#destroy'
  end
end