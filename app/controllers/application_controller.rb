# class ApplicationController < ActionController::Base
#   before_action :configure_permitted_parameters, if: :devise_controller?

#   protected

#   # Permit role during sign_up
#   def configure_permitted_parameters
#     devise_parameter_sanitizer.permit(:sign_up, keys: [:role])
#   end

#   # Role-based redirection
#   def after_sign_in_path_for(resource)
#     session[:user_role] = resource.role

#     case resource.role
#     when "employee"
#       employee_dashboard_path
#     when "hod"
#       hod_dashboard_path
#     when "l1_employer"
#       l1_dashboard_path
#     when "l2_employer"
#       l2_dashboard_path
#     else
#       root_path
#     end
#   end

#   # After logout
#   def after_sign_out_path_for(_resource_or_scope)
#     new_user_session_path
#   end
# end
class ApplicationController < ActionController::Base
  before_action :configure_permitted_parameters, if: :devise_controller?

  protected

  # Allow role param during sign-up
  def configure_permitted_parameters
    devise_parameter_sanitizer.permit(:sign_up, keys: [:role])
  end

  # ✅ Redirection after sign in (login)
  def after_sign_in_path_for(resource)
    session[:user_role] = resource.role

    case resource.role
    when "employee"
      employee_details_path
    # when "hod"
    #   hod_dashboard_path
    # when "l1_employer"
    #   l1_dashboard_path
    # when "l2_employer"
    #   l2_dashboard_path
    else
      root_path
    end
  end

  # ✅ Redirection after sign up
  def after_sign_up_path_for(resource)
    after_sign_in_path_for(resource)
  end

  # ✅ Redirection after logout
  def after_sign_out_path_for(_resource_or_scope)
    new_user_session_path
  end
end
