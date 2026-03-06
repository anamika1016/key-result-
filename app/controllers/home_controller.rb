class HomeController < ApplicationController
   before_action :authenticate_user!

  def index
  end

  def dashboard
    # Only allow HOD to access the main dashboard
    unless current_user.hod?
      if EmployeeDetail.exists?(l2_code: current_user.employee_code) || EmployeeDetail.exists?(l2_employer_name: current_user.email)
        redirect_to l2_employee_details_path and return
      end

      if EmployeeDetail.exists?(l1_code: current_user.employee_code)
        redirect_to l1_employee_details_path and return
      end

      if current_user.employee?
        redirect_to get_user_detail_user_details_path and return
      end

      # fallback if none of above
      render plain: "No dashboard or redirect for your role."
      return
    end

    # Calculate dashboard statistics for HOD
    @total_users = User.count  # Count total users in the system

    # FIXED: Use same quarter-based counting logic as L1/L2/L3 pages for consistency
    # This counts employee-quarter combinations, which is more meaningful for management

    # Get all employee details with achievements
    employee_details = EmployeeDetail.includes(
      user_details: [
        :activity,
        :department,
        { achievements: :achievement_remark }
      ]
    ).joins(user_details: :achievements).distinct

    # Initialize counters
    @l1_approved_count = 0
    @l2_approved_count = 0
    @l3_approved_count = 0
    @l1_returned_count = 0
    @l2_returned_count = 0
    @l3_returned_count = 0
    @l1_pending_count = 0
    @l2_pending_count = 0
    @l3_pending_count = 0
    @total_employee_details = 0

    quarters = {
      "Q1" => [ "april", "may", "june" ],
      "Q2" => [ "july", "august", "september" ],
      "Q3" => [ "october", "november", "december" ],
      "Q4" => [ "january", "february", "march" ]
    }

    processed_quarters = {}

    # Process each employee and quarter combination (same logic as L1/L2/L3 pages)
    employee_details.each do |emp|
      quarters.each do |quarter_name, quarter_months|
        # Create unique key for employee + quarter combination
        quarter_key = "#{emp.id}_#{quarter_name}"
        next if processed_quarters[quarter_key]

        # Get all achievements for this employee in this quarter
        monthly_achievements = emp.user_details.flat_map(&:achievements).select { |ach| quarter_months.include?(ach.month) }

        # Also check for quarterly format achievements (q1, q2, q3, q4)
        quarterly_achievements = emp.user_details.flat_map(&:achievements).select do |ach|
          case quarter_name
          when "Q1"
            ach.month == "q1"
          when "Q2"
            ach.month == "q2"
          when "Q3"
            ach.month == "q3"
          when "Q4"
            ach.month == "q4"
          else
            false
          end
        end

        # Combine both types of achievements
        all_quarter_achievements = monthly_achievements + quarterly_achievements

        # Only process quarters that have actual achievement data
        if all_quarter_achievements.any?
          processed_quarters[quarter_key] = true
          @total_employee_details += 1

          # Get all statuses for this quarter
          quarter_statuses = all_quarter_achievements.map { |ach| ach.status || "pending" }

          # Count based on overall status for this quarter - FIXED: Show counts at each level where approved
          # Check each level independently to show proper counts
          if quarter_statuses.any? { |s| s == "l3_approved" }
            @l3_approved_count += 1
          end
          if quarter_statuses.any? { |s| s == "l3_returned" }
            @l3_returned_count += 1
          end
          if quarter_statuses.any? { |s| s == "l2_approved" }
            @l2_approved_count += 1
          end
          if quarter_statuses.any? { |s| s == "l2_returned" }
            @l2_returned_count += 1
          end
          if quarter_statuses.any? { |s| s == "l1_approved" }
            @l1_approved_count += 1
          end
          if quarter_statuses.any? { |s| s == "l1_returned" }
            @l1_returned_count += 1
          end

          # Only count as pending if no approvals have been made at any level
          if quarter_statuses.none? { |s| [ "l1_approved", "l2_approved", "l3_approved", "l1_returned", "l2_returned", "l3_returned" ].include?(s) }
            @l1_pending_count += 1
          end
        end
      end
    end

    # Calculate pending counts for L2 and L3 (records that are ready for their review)
    # FIXED: Calculate actual pending counts based on what's ready for each level
    @l2_pending_count = 0
    @l3_pending_count = 0

    # Count records that are ready for L2 review (L1 approved but not yet L2 approved/returned)
    employee_details.each do |emp|
      quarters.each do |quarter_name, quarter_months|
        quarter_key = "#{emp.id}_#{quarter_name}"
        next if processed_quarters[quarter_key]

        # Get all achievements for this employee in this quarter
        monthly_achievements = emp.user_details.flat_map(&:achievements).select { |ach| quarter_months.include?(ach.month) }

        # Also check for quarterly format achievements (q1, q2, q3, q4)
        quarterly_achievements = emp.user_details.flat_map(&:achievements).select do |ach|
          case quarter_name
          when "Q1"
            ach.month == "q1"
          when "Q2"
            ach.month == "q2"
          when "Q3"
            ach.month == "q3"
          when "Q4"
            ach.month == "q4"
          else
            false
          end
        end

        all_quarter_achievements = monthly_achievements + quarterly_achievements

        if all_quarter_achievements.any?
          quarter_statuses = all_quarter_achievements.map { |ach| ach.status || "pending" }

          # L2 pending: L1 approved but not yet L2 approved/returned
          if quarter_statuses.any? { |s| s == "l1_approved" } &&
             quarter_statuses.none? { |s| [ "l2_approved", "l2_returned", "l3_approved", "l3_returned" ].include?(s) }
            @l2_pending_count += 1
          end

          # L3 pending: L2 approved but not yet L3 approved/returned
          if quarter_statuses.any? { |s| s == "l2_approved" } &&
             quarter_statuses.none? { |s| [ "l3_approved", "l3_returned" ].include?(s) }
            @l3_pending_count += 1
          end
        end
      end
    end

    # Total achievements count
    @total_achievements = Achievement.count

    # Count users by role - FIXED: Ensure all variables are properly set
    @employee_count = User.where(role: "employee").count  # Count employee users
    @hod_count = User.where(role: "hod").count  # This is the "Super Admin" count

    # Count actual L1 and L2 employers (users assigned as employers in employee_details)
    @l1_employer_count = User.joins("INNER JOIN employee_details ON employee_details.l1_code = users.employee_code OR employee_details.l1_employer_name = users.email")
                             .distinct.count

    @l2_employer_count = User.joins("INNER JOIN employee_details ON employee_details.l2_code = users.employee_code OR employee_details.l2_employer_name = users.email")
                             .distinct.count

    # Additional role counts
    @admin_count = User.where(role: "hod").count  # HOD is the admin role

    # Count users who have L1, L2, L3 responsibilities (not just their role)
    @l1_user_count = User.joins("LEFT JOIN employee_details ON employee_details.l1_code = users.employee_code OR employee_details.l1_employer_name = users.email")
                         .where("employee_details.l1_code IS NOT NULL OR employee_details.l1_employer_name IS NOT NULL OR users.role = 'hod'")
                         .distinct.count

    @l2_user_count = User.joins("LEFT JOIN employee_details ON employee_details.l2_code = users.employee_code OR employee_details.l2_employer_name = users.email")
                         .where("employee_details.l2_code IS NOT NULL OR employee_details.l2_employer_name IS NOT NULL OR users.role = 'hod'")
                         .distinct.count

    @l3_user_count = User.joins("LEFT JOIN employee_details ON employee_details.l3_code = users.employee_code OR employee_details.l3_employer_name = users.email")
                         .where("employee_details.l3_code IS NOT NULL OR employee_details.l3_employer_name IS NOT NULL OR users.role = 'hod'")
                         .distinct.count

    # Count departments and activities - FIXED: Ensure @total_departments is set
    @total_departments = Department.count
    @total_activities = Activity.count
    @total_user_details = UserDetail.count
  end

  def update_dashboard_status
    if current_user.hod?
      status = params[:active] == "true" || params[:active] == true
      SystemSetting.set_dashboard_active(status)
      render json: { success: true, active: status }
    else
      render json: { success: false, error: "Unauthorized" }, status: :unauthorized
    end
  end

  def submitted_view_data
    # Filter data based on user role and permissions, showing records with either achievements OR quarterly data
    case current_user.role
    when "employee"
      # Show current employee's data that has either achievements OR quarterly targets
      # STRICT FILTERING: Match by BOTH email AND employee_code to ensure we ONLY get current user's data
      # This prevents showing other users' data even if they have similar employee_codes

      # Build strict query - must match BOTH email AND employee_code
      employee_details = EmployeeDetail.all

      # Apply strict filtering conditions
      if current_user.employee_code.present? && current_user.email.present?
        # Most secure: match BOTH email AND employee_code
        employee_details = employee_details.where(
          employee_code: current_user.employee_code,
          employee_email: current_user.email
        )
      elsif current_user.employee_code.present?
        # Fallback: match by employee_code only if email not available
        employee_details = employee_details.where(employee_code: current_user.employee_code)
      elsif current_user.email.present?
        # Fallback: match by email only if employee_code not available
        employee_details = employee_details.where(employee_email: current_user.email)
      else
        # No matching criteria - show nothing
        employee_details = EmployeeDetail.none
      end

      # Additional safety: Filter UserDetails directly by current user's email/employee_code
      # This double-checks to ensure we never show wrong data
      if employee_details.any?
        employee_detail_ids = employee_details.pluck(:id)

        # Deduplicate by activity and department to avoid showing duplicate entries
        # when user has multiple employee_detail records for the same activities
        min_ids = UserDetail.where(employee_detail_id: employee_detail_ids)
                           .group(:activity_id, :department_id)
                           .minimum(:id)

        # Build the query with strict filtering
        @user_details = UserDetail.includes(:department, :activity, :employee_detail, achievements: :achievement_remark)
                                  .where(id: min_ids.values)
                                  .joins(:employee_detail)

        # Apply strict filtering - must match current user's credentials
        if current_user.employee_code.present? && current_user.email.present?
          @user_details = @user_details.where(employee_details: {
            employee_code: current_user.employee_code,
            employee_email: current_user.email
          })
        elsif current_user.employee_code.present?
          @user_details = @user_details.where(employee_details: { employee_code: current_user.employee_code })
        elsif current_user.email.present?
          @user_details = @user_details.where(employee_details: { employee_email: current_user.email })
        else
          # No credentials - show nothing for security
          @user_details = UserDetail.none
        end

        @user_details = @user_details.order("departments.department_type, activities.activity_name")

        # Log for debugging if we found data
        if @user_details.any?
          Rails.logger.info "Submitted View Data - Employee role: Found #{@user_details.count} records for user #{current_user.email} (#{current_user.employee_code})"
          @user_details.each do |ud|
            Rails.logger.info "  - Employee: #{ud.employee_detail.employee_name}, Email: #{ud.employee_detail.employee_email}, Code: #{ud.employee_detail.employee_code}"
          end
        end

        # Force a fresh database query to ensure we get the latest data
        # This is especially important after updates
        if params[:updated] == "true" || params[:refresh].present?
          Rails.logger.info "Forcing fresh database query in submitted_view_data due to update/refresh parameters"
          # Re-query the database to get fresh data
          fresh_user_detail_ids = @user_details.pluck(:id)
          @user_details = UserDetail.includes(:department, :activity, :employee_detail, achievements: :achievement_remark)
                                  .where(id: fresh_user_detail_ids)
                                  .order("departments.department_type, activities.activity_name")
        end

        # Force reload achievements to get fresh data from database
        # Clear all cached associations first
        @user_details.each do |user_detail|
          # Clear cached associations
          user_detail.association(:achievements).reset
          user_detail.association(:department).reset
          user_detail.association(:activity).reset
          user_detail.association(:employee_detail).reset

          # Reload the record and its associations
          user_detail.reload
          user_detail.achievements.reload

          # Force reload each achievement individually to ensure fresh data
          user_detail.achievements.each do |achievement|
            achievement.reload
          end
        end
      else
        @user_details = UserDetail.none
      end
    when "hod"
      # Show all data for HOD that has either achievements OR quarterly targets
      # FIXED: Apply deduplication to prevent duplicate entries
      min_ids = UserDetail.group(:activity_id, :department_id, :employee_detail_id)
                          .minimum(:id)

      @user_details = UserDetail.includes(:department, :activity, :employee_detail, achievements: :achievement_remark)
                                .where(id: min_ids.values)
                                .where(
                                  "EXISTS (SELECT 1 FROM achievements WHERE achievements.user_detail_id = user_details.id AND achievements.achievement IS NOT NULL AND achievements.achievement != '') OR
                                   (user_details.q1 IS NOT NULL AND user_details.q1 != '') OR
                                   (user_details.q2 IS NOT NULL AND user_details.q2 != '') OR
                                   (user_details.q3 IS NOT NULL AND user_details.q3 != '') OR
                                   (user_details.q4 IS NOT NULL AND user_details.q4 != '')"
                                )
                                .order("departments.department_type, employee_details.employee_name, activities.activity_name")

      # Force a fresh database query to ensure we get the latest data
      # This is especially important after updates
      if params[:updated] == "true" || params[:refresh].present?
        Rails.logger.info "Forcing fresh database query in submitted_view_data (HOD) due to update/refresh parameters"
        # Re-query the database to get fresh data
        fresh_user_detail_ids = @user_details.pluck(:id)
        @user_details = UserDetail.includes(:department, :activity, :employee_detail, achievements: :achievement_remark)
                                .where(id: fresh_user_detail_ids)
                                .where(
                                  "EXISTS (SELECT 1 FROM achievements WHERE achievements.user_detail_id = user_details.id AND achievements.achievement IS NOT NULL AND achievements.achievement != '') OR
                                   (user_details.q1 IS NOT NULL AND user_details.q1 != '') OR
                                   (user_details.q2 IS NOT NULL AND user_details.q2 != '') OR
                                   (user_details.q3 IS NOT NULL AND user_details.q3 != '') OR
                                   (user_details.q4 IS NOT NULL AND user_details.q4 != '')"
                                )
                                .order("departments.department_type, employee_details.employee_name, activities.activity_name")
      end

      # Force reload achievements to get fresh data from database
      # Clear all cached associations first
      @user_details.each do |user_detail|
        # Clear cached associations
        user_detail.association(:achievements).reset
        user_detail.association(:department).reset
        user_detail.association(:activity).reset
        user_detail.association(:employee_detail).reset

        # Reload the record and its associations
        user_detail.reload
        user_detail.achievements.reload

        # Force reload each achievement individually to ensure fresh data
        user_detail.achievements.each do |achievement|
          achievement.reload
        end
      end
    when "l1_employer"
      # Show data for employees under this L1 that has either achievements OR quarterly targets
      # FIXED: Apply deduplication to prevent duplicate entries
      employee_details = EmployeeDetail.where(l1_code: current_user.employee_code)

      if employee_details.any?
        employee_detail_ids = employee_details.pluck(:id)

        # Deduplicate by activity and department to avoid showing duplicate entries
        min_ids = UserDetail.where(employee_detail_id: employee_detail_ids)
                           .group(:activity_id, :department_id)
                           .minimum(:id)

        @user_details = UserDetail.includes(:department, :activity, :employee_detail, achievements: :achievement_remark)
                                  .where(id: min_ids.values)
                                  .where(
                                    "EXISTS (SELECT 1 FROM achievements WHERE achievements.user_detail_id = user_details.id AND achievements.achievement IS NOT NULL AND achievements.achievement != '') OR
                                     (user_details.q1 IS NOT NULL AND user_details.q1 != '') OR
                                     (user_details.q2 IS NOT NULL AND user_details.q2 != '') OR
                                     (user_details.q3 IS NOT NULL AND user_details.q3 != '') OR
                                     (user_details.q4 IS NOT NULL AND user_details.q4 != '')"
                                  )
                                  .order("departments.department_type, employee_details.employee_name, activities.activity_name")

        # Force a fresh database query to ensure we get the latest data
        # This is especially important after updates
        if params[:updated] == "true" || params[:refresh].present?
          Rails.logger.info "Forcing fresh database query in submitted_view_data (L1) due to update/refresh parameters"
          # Re-query the database to get fresh data
          fresh_user_detail_ids = @user_details.pluck(:id)
          @user_details = UserDetail.includes(:department, :activity, :employee_detail, achievements: :achievement_remark)
                                  .where(id: fresh_user_detail_ids)
                                  .where(
                                    "EXISTS (SELECT 1 FROM achievements WHERE achievements.user_detail_id = user_details.id AND achievements.achievement IS NOT NULL AND achievements.achievement != '') OR
                                     (user_details.q1 IS NOT NULL AND user_details.q1 != '') OR
                                     (user_details.q2 IS NOT NULL AND user_details.q2 != '') OR
                                     (user_details.q3 IS NOT NULL AND user_details.q3 != '') OR
                                     (user_details.q4 IS NOT NULL AND user_details.q4 != '')"
                                  )
                                  .order("departments.department_type, employee_details.employee_name, activities.activity_name")
        end

        # Force reload achievements to get fresh data from database
        # Clear all cached associations first
        @user_details.each do |user_detail|
          # Clear cached associations
          user_detail.association(:achievements).reset
          user_detail.association(:department).reset
          user_detail.association(:activity).reset
          user_detail.association(:employee_detail).reset

          # Reload the record and its associations
          user_detail.reload
          user_detail.achievements.reload

          # Force reload each achievement individually to ensure fresh data
          user_detail.achievements.each do |achievement|
            achievement.reload
          end
        end
      else
        @user_details = UserDetail.none
      end
    when "l2_employer"
      # Show data for employees under this L2 that has either achievements OR quarterly targets
      # FIXED: Apply deduplication to prevent duplicate entries
      employee_details = EmployeeDetail.where("l2_code = ? OR l2_employer_name = ?",
                                              current_user.employee_code, current_user.email)

      if employee_details.any?
        employee_detail_ids = employee_details.pluck(:id)

        # Deduplicate by activity and department to avoid showing duplicate entries
        min_ids = UserDetail.where(employee_detail_id: employee_detail_ids)
                           .group(:activity_id, :department_id)
                           .minimum(:id)

        @user_details = UserDetail.includes(:department, :activity, :employee_detail, achievements: :achievement_remark)
                                  .where(id: min_ids.values)
                                  .where(
                                    "EXISTS (SELECT 1 FROM achievements WHERE achievements.user_detail_id = user_details.id AND achievements.achievement IS NOT NULL AND achievements.achievement != '') OR
                                     (user_details.q1 IS NOT NULL AND user_details.q1 != '') OR
                                     (user_details.q2 IS NOT NULL AND user_details.q2 != '') OR
                                     (user_details.q3 IS NOT NULL AND user_details.q3 != '') OR
                                     (user_details.q4 IS NOT NULL AND user_details.q4 != '')"
                                  )
                                  .order("departments.department_type, employee_details.employee_name, activities.activity_name")

        # Force a fresh database query to ensure we get the latest data
        # This is especially important after updates
        if params[:updated] == "true" || params[:refresh].present?
          Rails.logger.info "Forcing fresh database query in submitted_view_data (L2) due to update/refresh parameters"
          # Re-query the database to get fresh data
          fresh_user_detail_ids = @user_details.pluck(:id)
          @user_details = UserDetail.includes(:department, :activity, :employee_detail, achievements: :achievement_remark)
                                  .where(id: fresh_user_detail_ids)
                                  .where(
                                    "EXISTS (SELECT 1 FROM achievements WHERE achievements.user_detail_id = user_details.id AND achievements.achievement IS NOT NULL AND achievements.achievement != '') OR
                                     (user_details.q1 IS NOT NULL AND user_details.q1 != '') OR
                                     (user_details.q2 IS NOT NULL AND user_details.q2 != '') OR
                                     (user_details.q3 IS NOT NULL AND user_details.q3 != '') OR
                                     (user_details.q4 IS NOT NULL AND user_details.q4 != '')"
                                  )
                                  .order("departments.department_type, employee_details.employee_name, activities.activity_name")
        end

        # Force reload achievements to get fresh data from database
        # Clear all cached associations first
        @user_details.each do |user_detail|
          # Clear cached associations
          user_detail.association(:achievements).reset
          user_detail.association(:department).reset
          user_detail.association(:activity).reset
          user_detail.association(:employee_detail).reset

          # Reload the record and its associations
          user_detail.reload
          user_detail.achievements.reload

          # Force reload each achievement individually to ensure fresh data
          user_detail.achievements.each do |achievement|
            achievement.reload
          end
        end
      else
        @user_details = UserDetail.none
      end
    else
      # Fallback - show no data for unknown roles
      @user_details = UserDetail.none
    end
  end

  def submitted_view_data_test
    # Simple test action
    render :submitted_view_data_test
  end

  def quarterly_details
    quarter = params[:quarter]

    # Security check: Check if dashboard is active
    dashboard_active = SystemSetting.dashboard_active?
    unless dashboard_active
      render json: { success: false, error: "Quarterly Achievement Details viewing has been disabled by the Administrator/HOD." }, status: :forbidden
      return
    end

    # Get quarterly data for the current user - include achievement_remark
    case current_user.role
    when "employee"
      # Use same strict filtering as submitted_view_data - match by both email and employee_code
      employee_details = EmployeeDetail.all

      if current_user.employee_code.present? && current_user.email.present?
        employee_details = employee_details.where(
          employee_code: current_user.employee_code,
          employee_email: current_user.email
        )
      elsif current_user.employee_code.present?
        employee_details = employee_details.where(employee_code: current_user.employee_code)
      elsif current_user.email.present?
        employee_details = employee_details.where(employee_email: current_user.email)
      else
        employee_details = EmployeeDetail.none
      end

      if employee_details.any?
        employee_detail_ids = employee_details.pluck(:id)
        min_ids = UserDetail.where(employee_detail_id: employee_detail_ids)
                           .group(:activity_id, :department_id)
                           .minimum(:id)

        user_details = UserDetail.includes(achievements: :achievement_remark)
                                .where(id: min_ids.values)
                                .joins(:employee_detail)

        if current_user.employee_code.present? && current_user.email.present?
          user_details = user_details.where(employee_details: {
            employee_code: current_user.employee_code,
            employee_email: current_user.email
          })
        elsif current_user.employee_code.present?
          user_details = user_details.where(employee_details: { employee_code: current_user.employee_code })
        elsif current_user.email.present?
          user_details = user_details.where(employee_details: { employee_email: current_user.email })
        else
          user_details = UserDetail.none
        end
      else
        user_details = UserDetail.none
      end
    when "hod"
      user_details = UserDetail.includes(:department, :employee_detail, achievements: :achievement_remark)
    when "l1_employer"
      user_details = UserDetail.includes(:department, :employee_detail, achievements: :achievement_remark)
                              .joins(:employee_detail)
                              .where(employee_details: { l1_code: current_user.employee_code })
    when "l2_employer"
      user_details = UserDetail.includes(:department, :employee_detail, achievements: :achievement_remark)
                              .joins(:employee_detail)
                              .where("employee_details.l2_code = ? OR employee_details.l2_employer_name = ?",
                                     current_user.employee_code, current_user.email)
    else
      user_details = UserDetail.none
    end

    # Group by employee_code and department_id to prevent duplicates for the same person
    grouped_details = user_details.group_by { |ud| [ ud.employee_detail&.employee_code, ud.department_id ] }

    department_summaries = grouped_details.map do |(emp_code, dept_id), details|
      first_detail = details.first
      dept = first_detail.department
      emp = first_detail.employee_detail

      {
        employee_name: emp&.employee_name || "N/A",
        department_name: dept&.department_type || "N/A",
        activity_count: details.size,
        l1: calculate_level_summary(details, quarter, "l1"),
        l2: calculate_level_summary(details, quarter, "l2"),
        l3: calculate_level_summary(details, quarter, "l3")
      }
    end.sort_by { |s| [ s[:employee_name], s[:department_name] ] }

    render json: {
      quarter: quarter,
      summaries: department_summaries,
      l1: calculate_level_summary(user_details, quarter, "l1"), # Keep old keys for backward compatibility
      l2: calculate_level_summary(user_details, quarter, "l2"),
      l3: calculate_level_summary(user_details, quarter, "l3")
    }
  end

  private

  def calculate_level_summary(user_details, quarter, level)
    # Get quarter months (both monthly and quarterly formats)
    quarter_months = quarter_to_months(quarter)
    quarter_key = quarter.downcase  # q1, q2, q3, q4

    # Get all achievements for this quarter (both monthly and quarterly formats)
    achievements = user_details.flat_map(&:achievements).select do |a|
      next false unless a.month
      month_lower = a.month.downcase
      quarter_months.include?(month_lower) || month_lower == quarter_key
    end

    if achievements.any?
      # Get achievements with achievement_remark
      achievements_with_remarks = achievements.select { |a| a.achievement_remark.present? }

      # Get statuses from achievements
      statuses = achievements.map(&:status).compact.uniq

      # Calculate level-specific data
      percentages = []
      remarks = []

      if achievements_with_remarks.any?
        # Calculate average percentage from achievement_remark for this level
        percentages = achievements_with_remarks.filter_map do |a|
          case level
          when "l1"
            a.achievement_remark.l1_percentage&.to_f
          when "l2"
            a.achievement_remark.l2_percentage&.to_f
          when "l3"
            a.achievement_remark.l3_percentage&.to_f
          end
        end.compact

        # Get remarks for this level
        remarks = achievements_with_remarks.filter_map do |a|
          case level
          when "l1"
            a.achievement_remark.l1_remarks
          when "l2"
            a.achievement_remark.l2_remarks
          when "l3"
            a.achievement_remark.l3_remarks
          end
        end.compact.uniq.reject(&:blank?)
      end

      # Check prerequisite levels first (hierarchy: L1 → L2 → L3)
      l1_approved = statuses.include?("l1_approved")
      l1_returned = statuses.include?("l1_returned")
      l2_approved = statuses.include?("l2_approved")
      l2_returned = statuses.include?("l2_returned")
      l3_approved = statuses.include?("l3_approved")
      l3_returned = statuses.include?("l3_returned")

      # Determine level-specific status based on hierarchy and data availability
      # IMPORTANT: Respect approval hierarchy - L1 must approve before L2, L2 must approve before L3
      level_status = case level
      when "l1"
        # L1 status: Check if L1 has provided data and what the achievement status is
        if percentages.any? || remarks.any?
          # L1 has provided data, check if it was approved or returned
          if l1_approved
            "L1 Approved"
          elsif l1_returned
            "L1 Returned"
          else
            "L1 Pending"
          end
        else
          "Pending"
        end
      when "l2"
        # L2 status: Can only be approved/returned if L1 is approved
        # IMPORTANT: L2 cannot be approved/returned if L1 is still pending
        if l1_approved
          # L1 is approved, now check L2 status
          if percentages.any? || remarks.any?
            # L2 has provided data, check if it was approved or returned
            if l2_approved
              "L2 Approved"
            elsif l2_returned
              "L2 Returned"
            else
              "L2 Pending"
            end
          else
            # L1 approved but L2 hasn't provided data yet
            "L2 Pending"
          end
        else
          # L1 not approved yet, so L2 must be pending (cannot proceed without L1 approval)
          "Pending"
        end
      when "l3"
        # L3 status: Can only be approved/returned if L2 is approved
        # IMPORTANT: L3 cannot be approved/returned if L2 is still pending
        if l2_approved
          # L2 is approved, now check L3 status
          if percentages.any? || remarks.any?
            # L3 has provided data, check if it was approved or returned
            if l3_approved
              "L3 Approved"
            elsif l3_returned
              "L3 Returned"
            else
              "L3 Pending"
            end
          else
            # L2 approved but L3 hasn't provided data yet
            "L3 Pending"
          end
        else
          # L2 not approved yet, so L3 must be pending (cannot proceed without L2 approval)
          "Pending"
        end
      else
        "Pending"
      end

      average_percentage = percentages.any? ? (percentages.sum / percentages.size).round(1) : 0.0

      {
        percentage: "#{average_percentage}%",
        remarks: remarks.any? ? remarks.join(", ") : "No remarks",
        status: level_status
      }
    else
      {
        percentage: "0.0%",
        remarks: "No data available",
        status: "No Data"
      }
    end
  end

  def quarter_to_months(quarter)
    case quarter
    when "Q1"
      [ "april", "may", "june" ]
    when "Q2"
      [ "july", "august", "september" ]
    when "Q3"
      [ "october", "november", "december" ]
    when "Q4"
      [ "january", "february", "march" ]
    else
      []
    end
  end
end
