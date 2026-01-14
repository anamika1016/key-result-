class ApprovalMailer < ApplicationMailer
  default from: "notification@ploughmanagro.com"

  # Quarterly L1 approval request email
  def quarterly_l1_approval_request(employee_detail, quarter, achievements, l1_email = nil)
    @employee = employee_detail
    @quarter = quarter
    @achievements = achievements

    # Use provided email or find L1 user by employee code
    if l1_email.present?
      target_email = l1_email
    else
      l1_user = User.find_by(employee_code: employee_detail.l1_code)
      target_email = l1_user&.email
    end

    if target_email.present?
      mail(
        to: target_email,
        subject: "📊 Quarterly Achievement Approval Required - #{@quarter} - #{@employee.employee_name}"
      )
    else
      Rails.logger.error "L1 email not found for employee code: #{employee_detail.l1_code}"
    end
  end

  # Quarterly L2 approval request email
  def quarterly_l2_approval_request(employee_detail, quarter, achievements)
    @employee = employee_detail
    @quarter = quarter
    @achievements = achievements

    # Find L2 user by employee code
    l2_user = User.find_by(employee_code: employee_detail.l2_code)

    if l2_user&.email.present?
      mail(
        to: l2_user.email,
        subject: "📊 Quarterly L2 Achievement Approval Required - #{@quarter} - #{@employee.employee_name}"
      )
    else
      Rails.logger.error "L2 user not found or email missing for employee code: #{employee_detail.l2_code}"
    end
  end

  # Quarterly L3 approval request email
  def quarterly_l3_approval_request(employee_detail, quarter, achievements)
    @employee = employee_detail
    @quarter = quarter
    @achievements = achievements

    # Find L3 user by employee code
    l3_user = User.find_by(employee_code: employee_detail.l3_code)

    if l3_user&.email.present?
      mail(
        to: l3_user.email,
        subject: "📊 Quarterly L3 Final Achievement Approval Required - #{@quarter} - #{@employee.employee_name}"
      )
    else
      Rails.logger.error "L3 user not found or email missing for employee code: #{employee_detail.l3_code}"
    end
  end

  # Individual L1 approval request email
  def l1_approval_request(achievement, l1_email)
    @achievement = achievement
    @employee = achievement.user_detail.employee_detail
    @user_detail = achievement.user_detail

    mail(
      to: l1_email,
      subject: "📊 Achievement Approval Required - #{@achievement.month.capitalize} - #{@employee.employee_name}"
    )
  end

  # Individual L2 approval request email
  def l2_approval_request(achievement, l2_email)
    @achievement = achievement
    @employee = achievement.user_detail.employee_detail
    @user_detail = achievement.user_detail

    mail(
      to: l2_email,
      subject: "📊 L2 Achievement Approval Required - #{@achievement.month.capitalize} - #{@employee.employee_name}"
    )
  end

  # Individual L3 approval request email
  def l3_approval_request(achievement, l3_email)
    @achievement = achievement
    @employee = achievement.user_detail.employee_detail
    @user_detail = achievement.user_detail

    mail(
      to: l3_email,
      subject: "📊 L3 Final Achievement Approval Required - #{@achievement.month.capitalize} - #{@employee.employee_name}"
    )
  end

  # Achievement approved email
  def achievement_approved(achievement, approver_email)
    @achievement = achievement
    @employee = achievement.user_detail.employee_detail
    @user_detail = achievement.user_detail

    mail(
      to: @employee.employee_email,
      subject: "✅ Achievement Approved - #{@achievement.month.capitalize} - #{@employee.employee_name}"
    )
  end

  # Achievement returned email
  def achievement_returned(achievement, approver_email)
    @achievement = achievement
    @employee = achievement.user_detail.employee_detail
    @user_detail = achievement.user_detail

    mail(
      to: @employee.employee_email,
      subject: "⚠️ Achievement Returned for Revision - #{@achievement.month.capitalize} - #{@employee.employee_name}"
    )
  end

  # Quarterly L1 approval notification to user
  def quarterly_l1_approved(employee_detail, quarter, achievements)
    @employee = employee_detail
    @quarter = quarter
    @achievements = achievements

    mail(
      to: @employee.employee_email,
      subject: "✅ L1 Quarterly Approval - #{@quarter} - #{@employee.employee_name}"
    )
  end

  # Quarterly L1 return notification to user
  def quarterly_l1_returned(employee_detail, quarter, achievements)
    @employee = employee_detail
    @quarter = quarter
    @achievements = achievements

    mail(
      to: @employee.employee_email,
      subject: "⚠️ L1 Quarterly Returned for Revision - #{@quarter} - #{@employee.employee_name}"
    )
  end

  # Quarterly L2 approval notification to user
  def quarterly_l2_approved(employee_detail, quarter, achievements)
    @employee = employee_detail
    @quarter = quarter
    @achievements = achievements

    mail(
      to: @employee.employee_email,
      subject: "✅ L2 Quarterly Approval - #{@quarter} - #{@employee.employee_name}"
    )
  end

  # Quarterly L2 return notification to user
  def quarterly_l2_returned(employee_detail, quarter, achievements)
    @employee = employee_detail
    @quarter = quarter
    @achievements = achievements

    mail(
      to: @employee.employee_email,
      subject: "⚠️ L2 Quarterly Returned for Revision - #{@quarter} - #{@employee.employee_name}"
    )
  end

  # Quarterly L3 approval notification to user
  def quarterly_l3_approved(employee_detail, quarter, achievements)
    @employee = employee_detail
    @quarter = quarter
    @achievements = achievements

    mail(
      to: @employee.employee_email,
      subject: "✅ L3 Final Quarterly Approval - #{@quarter} - #{@employee.employee_name}"
    )
  end

  # Quarterly L3 return notification to user
  def quarterly_l3_returned(employee_detail, quarter, achievements)
    @employee = employee_detail
    @quarter = quarter
    @achievements = achievements

    mail(
      to: @employee.employee_email,
      subject: "⚠️ L3 Quarterly Returned for Revision - #{@quarter} - #{@employee.employee_name}"
    )
  end

  # Individual L1 approval notification to user
  def l1_approved(achievement)
    @achievement = achievement
    @employee = achievement.user_detail.employee_detail
    @user_detail = achievement.user_detail

    mail(
      to: @employee.employee_email,
      subject: "✅ L1 Achievement Approved - #{@achievement.month.capitalize} - #{@employee.employee_name}"
    )
  end

  # Individual L1 return notification to user
  def l1_returned(achievement)
    @achievement = achievement
    @employee = achievement.user_detail.employee_detail
    @user_detail = achievement.user_detail

    mail(
      to: @employee.employee_email,
      subject: "⚠️ L1 Achievement Returned for Revision - #{@achievement.month.capitalize} - #{@employee.employee_name}"
    )
  end

  # Individual L2 approval notification to user
  def l2_approved(achievement)
    @achievement = achievement
    @employee = achievement.user_detail.employee_detail
    @user_detail = achievement.user_detail

    mail(
      to: @employee.employee_email,
      subject: "✅ L2 Achievement Approved - #{@achievement.month.capitalize} - #{@employee.employee_name}"
    )
  end

  # Individual L2 return notification to user
  def l2_returned(achievement)
    @achievement = achievement
    @employee = achievement.user_detail.employee_detail
    @user_detail = achievement.user_detail

    mail(
      to: @employee.employee_email,
      subject: "⚠️ L2 Achievement Returned for Revision - #{@achievement.month.capitalize} - #{@employee.employee_name}"
    )
  end

  # Individual L3 approval notification to user
  def l3_approved(achievement)
    @achievement = achievement
    @employee = achievement.user_detail.employee_detail
    @user_detail = achievement.user_detail

    mail(
      to: @employee.employee_email,
      subject: "✅ L3 Final Achievement Approved - #{@achievement.month.capitalize} - #{@employee.employee_name}"
    )
  end

  # Individual L3 return notification to user
  def l3_returned(achievement)
    @achievement = achievement
    @employee = achievement.user_detail.employee_detail
    @user_detail = achievement.user_detail

    mail(
      to: @employee.employee_email,
      subject: "⚠️ L3 Achievement Returned for Revision - #{@achievement.month.capitalize} - #{@employee.employee_name}"
    )
  end

  # Achievement returned to employee for refilling
  def achievement_returned_to_employee(achievement, employee_email)
    @achievement = achievement
    @employee = achievement.user_detail.employee_detail
    @user_detail = achievement.user_detail

    mail(
      to: employee_email,
      subject: "🔄 KRA Returned for Refilling - #{@achievement.month.capitalize} - #{@employee.employee_name}"
    )
  end

  # Quarterly achievement returned to employee for refilling
  def quarterly_achievement_returned_to_employee(employee_detail, quarter, achievements)
    @employee = employee_detail
    @quarter = quarter
    @achievements = achievements

    mail(
      to: @employee.employee_email,
      subject: "🔄 KRA Returned for Refilling - #{@quarter} - #{@employee.employee_name}"
    )
  end

  # L2 Return to Employee - Quarterly
  def l2_quarterly_returned_to_employee(employee_detail, quarter, achievements)
    @employee = employee_detail
    @quarter = quarter
    @achievements = achievements

    mail(
      to: @employee.employee_email,
      subject: "⚠️ L2 Returned KRA for Refilling - #{@quarter} - #{@employee.employee_name}"
    )
  end

  # L2 Return to L1 - Quarterly
  def l2_quarterly_returned_to_l1(employee_detail, quarter, achievements)
    @employee = employee_detail
    @quarter = quarter
    @achievements = achievements

    # Find L1 user by employee code
    l1_user = User.find_by(employee_code: employee_detail.l1_code)

    if l1_user&.email.present?
      mail(
        to: l1_user.email,
        subject: "⚠️ L2 Returned KRA for L1 Review - #{@quarter} - #{@employee.employee_name}"
      )
    else
      Rails.logger.error "L1 user not found or email missing for employee code: #{employee_detail.l1_code}"
    end
  end

  # L3 Return to Employee - Quarterly
  def l3_quarterly_returned_to_employee(employee_detail, quarter, achievements)
    @employee = employee_detail
    @quarter = quarter
    @achievements = achievements

    mail(
      to: @employee.employee_email,
      subject: "⚠️ L3 Returned KRA for Refilling - #{@quarter} - #{@employee.employee_name}"
    )
  end

  # L3 Return to L1 - Quarterly
  def l3_quarterly_returned_to_l1(employee_detail, quarter, achievements)
    @employee = employee_detail
    @quarter = quarter
    @achievements = achievements

    # Find L1 user by employee code
    l1_user = User.find_by(employee_code: employee_detail.l1_code)

    if l1_user&.email.present?
      mail(
        to: l1_user.email,
        subject: "⚠️ L3 Returned KRA for L1 Review - #{@quarter} - #{@employee.employee_name}"
      )
    else
      Rails.logger.error "L1 user not found or email missing for employee code: #{employee_detail.l1_code}"
    end
  end

  # L3 Return to L2 - Quarterly
  def l3_quarterly_returned_to_l2(employee_detail, quarter, achievements)
    @employee = employee_detail
    @quarter = quarter
    @achievements = achievements

    # Find L2 user by employee code
    l2_user = User.find_by(employee_code: employee_detail.l2_code)

    if l2_user&.email.present?
      mail(
        to: l2_user.email,
        subject: "⚠️ L3 Returned KRA for L2 Review - #{@quarter} - #{@employee.employee_name}"
      )
    else
      Rails.logger.error "L2 user not found or email missing for employee code: #{employee_detail.l2_code}"
    end
  end

  # Quarterly submission confirmation email to employee
  def quarterly_submission_confirmation(employee_detail, quarter, achievements)
    @employee = employee_detail
    @quarter = quarter
    @achievements = achievements

    mail(
      to: @employee.employee_email,
      subject: "📝 Quarterly Achievement Submitted - #{@quarter} - #{@employee.employee_name}"
    )
  end
end
