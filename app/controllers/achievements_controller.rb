class AchievementsController < ApplicationController
  def new
    @user_detail = UserDetail.find(params[:user_detail_id])
    @months = %w[april may june july august september october november december january february march]
    @existing_achievements = @user_detail.achievements.index_by(&:month)
  end

  def create
    @user_detail = UserDetail.find(params[:user_detail_id])
    employee_detail = @user_detail.employee_detail
    submitted_achievements = []

    achievements_params.each do |month, achievement|
      next if achievement.blank?

      a = @user_detail.achievements.find_or_initialize_by(month: month)
      a.achievement = achievement
      # FIXED: Ensure status is set to pending for quarterly consistency
      a.status = "pending"
      if a.save
        submitted_achievements << a
      end
    end

    # Send email notification to L1 manager for individual achievement submissions
    if submitted_achievements.any? && employee_detail&.l1_code.present?
      send_individual_l1_email(employee_detail, submitted_achievements)
    end

    redirect_to user_detail_path(@user_detail), notice: "Achievements submitted successfully."
  end

  private

  def achievements_params
    params.require(:achievements).permit(
      *%w[april may june july august september october november december january february march]
    )
  end

  def send_individual_l1_email(employee_detail, achievements)
    # Find L1 user by employee code
    l1_user = User.find_by(employee_code: employee_detail.l1_code)

    # If L1 user not found, try to find L1 manager by employee code in EmployeeDetail
    if l1_user.nil?
      l1_manager = EmployeeDetail.find_by("employee_code LIKE ?", employee_detail.l1_code.strip + "%")
      if l1_manager&.employee_email.present?
        l1_email = l1_manager.employee_email
        Rails.logger.info "L1 user not found in users table, using employee email: #{l1_email}"
      else
        Rails.logger.error "L1 manager not found for employee code: #{employee_detail.l1_code}"
        return { success: false, message: "L1 manager not found" }
      end
    elsif l1_user&.email.present?
      l1_email = l1_user.email
    else
      Rails.logger.error "L1 user found but email missing for employee code: #{employee_detail.l1_code}"
      return { success: false, message: "L1 manager email not found" }
    end

    begin
      # Send individual emails for each achievement
      achievements.each do |achievement|
        Rails.logger.info "Sending individual L1 email to #{l1_email} for employee #{employee_detail.employee_name} - Month: #{achievement.month}"
        ApprovalMailer.l1_approval_request(achievement, l1_email).deliver_now
      end
      Rails.logger.info "Individual L1 emails sent successfully to #{l1_email} for #{achievements.count} achievements"
      { success: true, message: "Emails sent to L1 manager" }
    rescue => e
      Rails.logger.error "Failed to send individual L1 emails: #{e.message}"
      Rails.logger.error "Backtrace: #{e.backtrace.first(5).join("\n")}"
      { success: false, message: "Email sending failed: #{e.message}" }
    end
  end
end
