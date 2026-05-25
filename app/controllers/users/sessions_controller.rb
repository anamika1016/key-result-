require "openssl"

class Users::SessionsController < Devise::SessionsController
  skip_before_action :verify_authenticity_token, only: [ :create, :employee_code_sign_in ] # only for testing, enable CSRF later

  def new
    requested_code = params[:employee_code].to_s.strip

    if employee_code_auto_sign_in_allowed? && requested_code.present?
      sign_in_with_employee_code_from_employee_list(requested_code) and return
    end

    super
  end

  def employee_code_sign_in
    requested_code = params[:employee_code].to_s.strip
    normalized_requested_code = normalize_employee_code(requested_code)
    normalized_current_code = normalize_employee_code(current_user&.employee_code)

    if valid_external_sign_in_request?(requested_code)
      sign_in_with_employee_code_from_employee_list(requested_code)
    elsif external_sign_in_params_present?
      sign_out(resource_name) if user_signed_in?
      flash[:alert] = "Invalid or expired sign in link. Please sign in again."
      redirect_to new_session_path(resource_name, employee_code: requested_code, auto_sign_in: "0")
    elsif user_signed_in? && normalized_requested_code.present? && normalized_current_code == normalized_requested_code
      redirect_to after_sign_in_path_for(current_user)
    elsif requested_code.present?
      sign_in_with_employee_code_from_employee_list(requested_code)
    else
      if user_signed_in?
        sign_out(resource_name)
        flash[:alert] = "Employee code does not match. Please sign in with the correct employee code."
      end

      redirect_to new_session_path(resource_name, employee_code: requested_code)
    end
  end

  def create
    submitted_password = params[:user][:password]
    submitted_code = params[:user][:employee_code]&.strip

    # Validate required fields
    if submitted_password.blank?
      flash[:alert] = "Please enter your password."
      redirect_to new_session_path(resource_name) and return
    end

    if submitted_code.blank?
      flash[:alert] = "Please enter your employee code."
      redirect_to new_session_path(resource_name) and return
    end

    user = User.where("lower(employee_code) = ?", submitted_code.downcase).first

    if user.nil?
      flash[:alert] = "No account found with that employee code. Please check your employee code and try again."
      redirect_to new_session_path(resource_name) and return
    end

    unless user.valid_password?(submitted_password)
      flash[:alert] = "Incorrect password. Please check your password and try again."
      redirect_to new_session_path(resource_name) and return
    end

    sign_in(resource_name, user)
    flash[:notice] = "Welcome back, #{user.display_name}!"
    redirect_to after_sign_in_path_for(user)
  end

  protected

  def after_sign_in_path_for(resource)
    settings_path
  end

  private

  def normalize_employee_code(employee_code)
    employee_code.to_s.strip.downcase.presence
  end

  def valid_external_sign_in_request?(employee_code)
    expires_at = params[:expires_at].to_s
    signature = params[:signature].to_s

    return false if employee_code.blank? || expires_at.blank? || signature.blank? || sso_secret.blank?
    return false if Time.at(Integer(expires_at)) < Time.current

    expected_signature = OpenSSL::HMAC.hexdigest("SHA256", sso_secret, external_sign_in_payload(employee_code, expires_at))
    secure_compare(signature, expected_signature)
  rescue ArgumentError
    false
  end

  def sign_in_with_employee_code_from_employee_list(employee_code)
    employee_detail = employee_detail_for_code(employee_code)
    user = user_for_employee_detail(employee_detail)

    if user
      sign_out(resource_name) if user_signed_in? && current_user != user
      sign_in(resource_name, user)
      flash[:notice] = "Welcome back, #{user.display_name}!"
      redirect_to external_sign_in_redirect_path(user)
    else
      sign_out(resource_name) if user_signed_in?
      flash[:alert] = "No account found with that employee code. Please check your employee code and try again."
      redirect_to new_session_path(resource_name, employee_code: employee_code, auto_sign_in: "0")
    end
  end

  def employee_detail_for_code(employee_code)
    normalized_code = normalize_employee_code(employee_code)
    return if normalized_code.blank?

    EmployeeDetail.where("LOWER(TRIM(employee_code)) = ?", normalized_code).first
  end

  def user_for_employee_detail(employee_detail)
    return if employee_detail.blank?

    normalized_code = normalize_employee_code(employee_detail.employee_code)
    return if normalized_code.blank?

    user_for_employee_code(normalized_code) ||
      matching_employee_user(employee_detail.user, normalized_code) ||
      matching_employee_user(user_for_employee_email(employee_detail.employee_email), normalized_code) ||
      create_user_for_employee_detail(employee_detail)
  end

  def user_for_employee_code(employee_code)
    normalized_code = normalize_employee_code(employee_code)
    return if normalized_code.blank?

    User.where("LOWER(TRIM(employee_code)) = ?", normalized_code).first
  end

  def matching_employee_user(user, employee_code)
    return if user.blank?

    user if normalize_employee_code(user.employee_code) == normalize_employee_code(employee_code)
  end

  def user_for_employee_email(employee_email)
    normalized_email = employee_email.to_s.strip.downcase
    return if normalized_email.blank?

    User.where("LOWER(TRIM(email)) = ?", normalized_email).first
  end

  def create_user_for_employee_detail(employee_detail)
    normalized_email = employee_detail.employee_email.to_s.strip.downcase
    return if normalized_email.blank? || normalize_employee_code(employee_detail.employee_code).blank?

    existing_email_user = user_for_employee_email(normalized_email)
    return if existing_email_user.present?

    User.create!(
      email: normalized_email,
      employee_code: employee_detail.employee_code,
      password: UserCreationService::DEFAULT_PASSWORD,
      password_confirmation: UserCreationService::DEFAULT_PASSWORD,
      role: UserCreationService::DEFAULT_ROLE
    )
  rescue ActiveRecord::RecordInvalid => e
    Rails.logger.error "Failed to create user for employee #{employee_detail.employee_code}: #{e.message}"
    nil
  end

  def employee_code_auto_sign_in_allowed?
    params[:auto_sign_in].to_s != "0" && !external_sign_in_params_present?
  end

  def external_sign_in_params_present?
    params[:expires_at].present? || params[:signature].present?
  end

  def secure_compare(signature, expected_signature)
    ActiveSupport::SecurityUtils.secure_compare(signature, expected_signature)
  end

  def sso_secret
    ENV["ESS_SSO_SECRET"].presence || Rails.application.credentials.dig(:ess_sso_secret).presence
  end

  def external_sign_in_redirect_path(user)
    return after_sign_in_path_for(user) if params[:year].blank?

    dashboard_path(year: normalize_financial_year(params[:year]))
  end

  def external_sign_in_payload(employee_code, expires_at)
    return "#{employee_code}:#{expires_at}" if params[:year].blank?

    "#{employee_code}:#{normalize_financial_year(params[:year])}:#{expires_at}"
  end
end
