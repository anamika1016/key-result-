class SettingsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_user

  def show
    # Settings page - show user profile information
  end

  def update_profile
    if save_profile
      if request.xhr?
        # For AJAX requests, return JSON response
        render json: {
          success: true,
          message: "Profile updated successfully.",
          avatar_url: @user.avatar.attached? ? url_for(@user.avatar) : nil
        }
      else
        redirect_to settings_path, notice: "Profile updated successfully."
      end
    else
      if request.xhr?
        render json: {
          success: false,
          errors: @user.errors.full_messages
        }, status: :unprocessable_entity
      else
        render :show, status: :unprocessable_entity
      end
    end
  end

  def change_password
    if @user.update_with_password(password_params)
      bypass_sign_in(@user)
      redirect_to settings_path, notice: "Password changed successfully."
    else
      render :show, status: :unprocessable_entity
    end
  end

  private

  # Updates the user and, when a full name is submitted, the linked employee record's name.
  def save_profile
    full_name = params[:full_name]&.squish
    return @user.update(user_params) if full_name.nil?

    if full_name.blank?
      @user.assign_attributes(user_params)
      @user.errors.add(:base, "Full name can't be blank")
      return false
    end

    detail = @user.employee_detail || @employee_detail
    if detail.nil?
      @user.assign_attributes(user_params)
      @user.errors.add(:base, "No employee record is linked to your account. Please contact the admin to update your name.")
      return false
    end

    if detail.user_id.present? && detail.user_id != @user.id
      @user.assign_attributes(user_params)
      @user.errors.add(:base, "Your account is matched to another employee's record. Please contact the admin to fix the mapping.")
      return false
    end

    saved = false
    ActiveRecord::Base.transaction do
      raise ActiveRecord::Rollback unless @user.update(user_params)

      detail.user_id ||= @user.id
      detail.employee_name = full_name
      unless detail.save
        detail.errors.full_messages.each { |msg| @user.errors.add(:base, msg) }
        raise ActiveRecord::Rollback
      end
      saved = true
    end

    @user.instance_variable_set(:@mapped_employee_detail, detail) if saved
    saved
  end

  def set_user
    @user = current_user
    @employee_detail = @user.mapped_employee_detail
  end

  def user_params
    params.fetch(:user, {}).permit(:email, :employee_code, :avatar)
  end

  def password_params
    params.require(:user).permit(:current_password, :password, :password_confirmation)
  end
end
