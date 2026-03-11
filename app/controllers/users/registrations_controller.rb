# app/controllers/users/registrations_controller.rb
class Users::RegistrationsController < Devise::RegistrationsController
  before_action :configure_permitted_parameters

  protected

  def configure_permitted_parameters
    devise_parameter_sanitizer.permit(:sign_up, keys: [ :employee_code, :role ])
  end

  def after_sign_up_path_for(resource)
    settings_path
  end

  def after_inactive_sign_up_path_for(resource)
    settings_path
  end
end
