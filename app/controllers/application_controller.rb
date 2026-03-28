class ApplicationController < ActionController::Base
  before_action :authenticate_user!
  before_action :set_dashboard_active
  before_action :configure_permitted_parameters, if: :devise_controller?

  helper_method :has_l1_responsibilities?, :has_l2_responsibilities?, :current_financial_year_label, :normalize_financial_year, :financial_year_options, :display_financial_year, :database_financial_year_value

  private

  def set_dashboard_active
    @dashboard_active = SystemSetting.dashboard_active?
  end

  protected

  def configure_permitted_parameters
    devise_parameter_sanitizer.permit(:sign_in, keys: [ :employee_code, :role ])
    devise_parameter_sanitizer.permit(:sign_up, keys: [ :employee_code, :role ])
  end


  def has_l1_responsibilities?
    return true if current_user.hod?
    EmployeeDetail.exists?(l1_code: current_user.employee_code)
  end

  def has_l2_responsibilities?
    return true if current_user.hod?
    EmployeeDetail.exists?(l2_code: current_user.employee_code) ||
    EmployeeDetail.exists?(l2_employer_name: current_user.email)
  end

  # Override Devise's after_sign_in_path_for to always redirect to User Profile
  def after_sign_in_path_for(resource)
    settings_path
  end

  def current_financial_year_label(date = Date.current)
    start_year = date.month >= 4 ? date.year : date.year - 1
    end_year = start_year + 1
    "#{start_year.to_s[-2, 2]}-#{end_year.to_s[-2, 2]}"
  end

  def normalize_financial_year(raw_value)
    return current_financial_year_label if raw_value.blank?

    value = raw_value.to_s.strip
    return value if value.match?(/\A\d{2}-\d{2}\z/)
    return "#{value[2, 2]}-#{(value.to_i + 1).to_s[-2, 2]}" if value.match?(/\A\d{4}\z/)
    return "#{value[2, 2]}-#{value[7, 2]}" if value.match?(/\A\d{4}-\d{4}\z/)

    current_financial_year_label
  end

  def display_financial_year(raw_value)
    normalized = normalize_financial_year(raw_value)
    return normalized unless normalized.match?(/\A\d{2}-\d{2}\z/)

    start_year = "20#{normalized[0, 2]}"
    end_year = "20#{normalized[3, 2]}"
    "#{start_year}-#{end_year}"
  end

  def database_financial_year_value(model_or_relation, raw_value)
    normalized = normalize_financial_year(raw_value)
    klass = if model_or_relation.is_a?(Class)
      model_or_relation
    elsif model_or_relation.respond_to?(:klass)
      model_or_relation.klass
    else
      model_or_relation.class
    end

    year_column_type = klass.columns_hash["year"]&.type
    return normalized unless year_column_type == :integer

    2000 + normalized[0, 2].to_i
  end

  def financial_year_options(existing_values = [])
    current_start_year = Date.current.month >= 4 ? Date.current.year : Date.current.year - 1
    fallback = (-2..2).map do |offset|
      start_year = current_start_year + offset
      end_year = start_year + 1
      "#{start_year.to_s[-2, 2]}-#{end_year.to_s[-2, 2]}"
    end

    (Array(existing_values).compact.map { |value| normalize_financial_year(value) } + fallback).uniq.sort.reverse
  end
end
