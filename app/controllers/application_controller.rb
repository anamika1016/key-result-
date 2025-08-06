# app/controllers/application_controller.rb
class ApplicationController < ActionController::Base
  before_action :authenticate_user!
  before_action :configure_permitted_parameters, if: :devise_controller?

  protected

  # Only allow role param on sign up
  def configure_permitted_parameters
    devise_parameter_sanitizer.permit(:sign_in, keys: [:employee_code, :role])
    # For Sign Up
    devise_parameter_sanitizer.permit(:sign_up, keys: [:employee_code, :role])
  end

  # Redirect to dashboard based on role
  # def after_sign_in_path_for(resource)
  #   case resource.role
  #   when 'hod'
  #     new_user_detail_path
  #   when 'employee'
  #     employee_details_path
  #   when 'l1_employer'
  #     l1_employee_details_path
  #   when 'l2_employer'
  #     l2_employee_details_path
  #   else
  #     root_path
  #   end
  # end

    def has_l1_responsibilities?
      return true if current_user.hod?
      EmployeeDetail.exists?(l1_code: current_user.employee_code)
    end

    # Check if current user has any L2 responsibilities  
    def has_l2_responsibilities?
      return true if current_user.hod?
      EmployeeDetail.exists?(l2_code: current_user.employee_code) || 
      EmployeeDetail.exists?(l2_employer_name: current_user.email)
    end

  helper_method :has_l1_responsibilities?, :has_l2_responsibilities?

end
  