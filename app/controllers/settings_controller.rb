class SettingsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_user

  def show
    # Settings page - show user profile information
  end

  def update_profile
    if @user.update(user_params)
      if request.xhr?
        # For AJAX requests, return JSON response
        render json: {
          success: true,
          message: "Profile updated successfully.",
          avatar_url: @user.avatar.attached? ? rails_blob_path(@user.avatar, only_path: true) : nil
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

  def set_user
    @user = current_user
  end

  def user_params
    params.require(:user).permit(:email, :employee_code, :avatar)
  end

  def password_params
    params.require(:user).permit(:current_password, :password, :password_confirmation)
  end
end
