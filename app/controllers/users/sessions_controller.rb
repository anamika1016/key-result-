class Users::SessionsController < Devise::SessionsController
  skip_before_action :verify_authenticity_token, only: [ :create ] # only for testing, enable CSRF later

  def create
    submitted_email = params[:user][:email]&.strip&.downcase
    submitted_password = params[:user][:password]
    submitted_code = params[:user][:employee_code]&.strip

    # Validate required fields
    if submitted_email.blank?
      flash[:alert] = "Please enter your email address."
      redirect_to new_session_path(resource_name) and return
    end

    if submitted_password.blank?
      flash[:alert] = "Please enter your password."
      redirect_to new_session_path(resource_name) and return
    end

    if submitted_code.blank?
      flash[:alert] = "Please enter your employee code."
      redirect_to new_session_path(resource_name) and return
    end

    user = User.find_by(email: submitted_email)

    if user.nil?
      flash[:alert] = "❌ No account found with that email address. Please check your email and try again."
      redirect_to new_session_path(resource_name) and return
    end

    unless user.valid_password?(submitted_password)
      flash[:alert] = "❌ Incorrect password. Please check your password and try again."
      redirect_to new_session_path(resource_name) and return
    end

    unless user.employee_code == submitted_code
      flash[:alert] = "❌ Incorrect employee code. Please check your employee code and try again."
      redirect_to new_session_path(resource_name) and return
    end

    sign_in(resource_name, user)
    flash[:notice] = "✅ Welcome back, #{user.email}!"
    redirect_to after_sign_in_path_for(user)
  end
end
