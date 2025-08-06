# class Users::SessionsController < Devise::SessionsController
#   def create
#     submitted_role = params[:user][:role]
#     email = params[:user][:email]
#     password = params[:user][:password]

#     user = User.find_by(email: email)

#     Rails.logger.info "DEBUG: Submitted role: #{submitted_role.inspect}"
#     Rails.logger.info "DEBUG: User's actual role: #{user&.role.inspect}"

#     if user&.valid_password?(password)
#       if user.role.present? && submitted_role == user.role
#         sign_in(resource_name, user)
#         redirect_to after_sign_in_path_for(user)
#       else
#         flash[:alert] = "Invalid role selected for this user. Expected: '#{user.role}', Got: '#{submitted_role}'"
#         redirect_to root_path
#       end
#     else
#       flash[:alert] = "Invalid email or password."
#       redirect_to root_path
#     end
#   end
# end

# app/controllers/users/sessions_controller.rb
class Users::SessionsController < Devise::SessionsController
  skip_before_action :verify_authenticity_token, only: [:create] # only for testing, enable CSRF later

  def create
    submitted_email = params[:user][:email]
    submitted_password = params[:user][:password]
    # submitted_role = params[:user][:role]
    submitted_code = params[:user][:employee_code]&.strip

    user = User.find_by(email: submitted_email)

    if user.nil?
      flash[:alert] = "No account found with that email."
      redirect_to new_session_path(resource_name) and return
    end

    unless user.valid_password?(submitted_password)
      flash[:alert] = "Incorrect password."
      redirect_to new_session_path(resource_name) and return
    end

    # unless user.role == submitted_role
    #   flash[:alert] = "Incorrect role. Expected '#{user.role}'."
    #   redirect_to new_session_path(resource_name) and return
    # end

    unless user.employee_code == submitted_code
      flash[:alert] = "Incorrect employee code."
      redirect_to new_session_path(resource_name) and return
    end

    sign_in(resource_name, user)
    redirect_to after_sign_in_path_for(user)
  end
end
