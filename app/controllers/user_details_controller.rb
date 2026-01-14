class UserDetailsController < ApplicationController
  require "ostruct"
  require "set"
  before_action :set_user_detail, only: [ :show, :edit, :update, :destroy ]
  load_and_authorize_resource except: [ :index, :new, :create, :get_user_detail, :get_activities, :bulk_create, :submit_achievements, :export, :import, :quarterly_edit_all, :update_quarterly_achievements, :test_sms, :view_sms_logs, :export_excel ]
  skip_load_and_authorize_resource only: [ :update_quarterly_achievements ]

  def index
    if current_user.role == "employee" || current_user.role == "l1_employer" || current_user.role == "l2_employer"
      # FIXED: Find ALL employee details for this user (not just one)
      # A user can have multiple employee detail records for different departments
      employee_details = EmployeeDetail.where(employee_email: current_user.email)

      # If no results found with email, try with employee_code
      if employee_details.empty? && current_user.employee_code.present?
        employee_details = EmployeeDetail.where(employee_code: current_user.employee_code)
      end

      @user_details = if employee_details.any?
        # Get user details from ALL employee details that match this user
        # This ensures we show data from ALL departments the user belongs to
        employee_detail_ids = employee_details.pluck(:id)

        # FIXED: Deduplicate by activity and department to avoid showing duplicate entries
        # when user has multiple employee_detail records for the same activities
        # Use a subquery to get the minimum ID for each activity-department combination
        min_ids = UserDetail.where(employee_detail_id: employee_detail_ids)
                           .group(:activity_id, :department_id)
                           .minimum(:id)

        UserDetail.includes(:department, :activity, :employee_detail)
                  .where(id: min_ids.values)
                  .order("departments.department_type, activities.activity_name")
                  .page(params[:page]).per(50)
      else
        UserDetail.none.page(params[:page]).per(50)
      end

    elsif current_user.role == "hod"
      @user_details = UserDetail.includes(:department, :activity, :employee_detail)
                                .order("departments.department_type, employee_details.employee_name, activities.activity_name")
                                .page(params[:page]).per(50)
    end
  end

    def new
    @user_detail = UserDetail.new

    # Load unique departments - use group by to ensure no duplicates
    @departments = Department.group(:department_type).select("MIN(id) as id, department_type")

    # Filter employees based on selected department
    if params[:department_id].present?
      begin
        dept_type = Department.find(params[:department_id]).department_type
        # Find employees who have user_details in this department
        employee_ids = UserDetail.joins(:department)
                                 .where(departments: { department_type: dept_type })
                                 .pluck(:employee_detail_id)
                                 .uniq

        all_employees = EmployeeDetail.where(id: employee_ids)

        # Group by base employee code and get the first record for each
        unique_employees = {}
        all_employees.each do |emp|
          base_code = emp.employee_code.split("_").first
          unless unique_employees[base_code]
            unique_employees[base_code] = emp
          end
        end

        @employee_details = unique_employees.values.sort_by(&:employee_name)
      rescue ActiveRecord::RecordNotFound
        flash[:alert] = "Department not found."
        @employee_details = EmployeeDetail.none
      end
    else
      @employee_details = EmployeeDetail.none
    end

    # Find selected employee to show L1/L2
    if params[:employee_detail_id].present?
      begin
        @selected_employee = EmployeeDetail.find_by(id: params[:employee_detail_id])
      rescue ActiveRecord::RecordNotFound
        flash[:alert] = "Employee not found."
        @selected_employee = nil
      end
    end

    @users = User.select(:id, :email, :role) if params[:show_users]

    # Load employee-specific activities when both department and employee are selected
    if params[:department_id].present? && params[:employee_detail_id].present?
      begin
        # Get the department
        selected_department = Department.find(params[:department_id])

        # Get activities that have existing user_details with monthly targets filled for this SPECIFIC employee AND department
        # FIXED: Only use the selected employee, not all employees with the same base code
        selected_employee = EmployeeDetail.find(params[:employee_detail_id])

        # Get activities that have user_details with actual monthly data (not empty/null) for THIS SPECIFIC EMPLOYEE
        # Only show activities where at least one month has target data filled
        @employee_activities = UserDetail.includes(:activity)
                                       .where(employee_detail_id: params[:employee_detail_id])
                                       .where(department_id: params[:department_id])
                                       .where.not(activity_id: nil)
                                       .where("april IS NOT NULL AND april != '' OR
                                              may IS NOT NULL AND may != '' OR
                                              june IS NOT NULL AND june != '' OR
                                              july IS NOT NULL AND july != '' OR
                                              august IS NOT NULL AND august != '' OR
                                              september IS NOT NULL AND september != '' OR
                                              october IS NOT NULL AND october != '' OR
                                              november IS NOT NULL AND november != '' OR
                                              december IS NOT NULL AND december != '' OR
                                              january IS NOT NULL AND january != '' OR
                                              february IS NOT NULL AND february != '' OR
                                              march IS NOT NULL AND march != ''")
                                       .map(&:activity)
                                       .uniq

        # FIXED: Only load user_details when BOTH department and employee are selected
        # This prevents showing all data when only one filter is applied
        @user_details = UserDetail.includes(:department, :activity, :employee_detail)
                                  .where(filter_conditions)
                                  .limit(100)

        # Debug logging to check what data is being loaded
        Rails.logger.info "=== DEBUG: User Details Loading ==="
        Rails.logger.info "Department ID: #{params[:department_id]}"
        Rails.logger.info "Employee Detail ID: #{params[:employee_detail_id]}"
        Rails.logger.info "Filter conditions: #{filter_conditions}"
        Rails.logger.info "User details count: #{@user_details.count}"
        Rails.logger.info "User details employee names: #{@user_details.map(&:employee_detail).map(&:employee_name).uniq}"
        Rails.logger.info "=== END DEBUG ==="
      rescue ActiveRecord::RecordNotFound => e
        flash[:alert] = "Error loading data: #{e.message}"
        @employee_activities = []
        @user_details = UserDetail.none
      rescue => e
        flash[:alert] = "An error occurred while loading data."
        Rails.logger.error "Error in new action: #{e.message}"
        @employee_activities = []
        @user_details = UserDetail.none
      end
    else
      @employee_activities = []
      @user_details = UserDetail.none
    end
  end

  def create
    @user_detail = UserDetail.new(user_detail_params)

    if @user_detail.save
      redirect_to new_user_detail_path, notice: "User detail was successfully created."
    else
      load_form_data
      render :new
    end
  end

  def edit
    @departments = Department.select(:id, :department_type)
    @activities = Activity.select(:id, :activity_name, :unit, :theme_name)
                         .where(department_id: @user_detail.department_id)
  end

  def update
    begin
      # Store the current context before update
      department_id = @user_detail.department_id
      employee_detail_id = @user_detail.employee_detail_id

      # Extract activity fields from params
      activity_params = {
        theme_name: params[:user_detail][:activity_theme_name],
        unit: params[:user_detail][:activity_unit],
        weight: params[:user_detail][:activity_weight]
      }

      # Remove activity fields from user_detail_params
      user_detail_params_filtered = user_detail_params.except(:activity_theme_name, :activity_unit, :activity_weight)

      ActiveRecord::Base.transaction do
        # Update the user detail
        if @user_detail.update(user_detail_params_filtered)
          # Update the associated activity if activity fields are provided
          if @user_detail.activity.present? && activity_params.values.any?(&:present?)
            # Build update hash with only present values
            update_hash = {}
            update_hash[:theme_name] = activity_params[:theme_name] if activity_params[:theme_name].present?
            update_hash[:unit] = activity_params[:unit] if activity_params[:unit].present?
            update_hash[:weight] = activity_params[:weight] if activity_params[:weight].present?

            @user_detail.activity.update!(update_hash) if update_hash.any?
          end

          # Clear any existing flash messages
          flash.clear

          # Redirect based on user role
          if current_user.hod?
            redirect_to new_user_detail_path,
                        notice: "Target was successfully updated."
          else
            redirect_to user_details_path,
                        notice: "Target was successfully updated."
          end
        else
          @departments = Department.select(:id, :department_type)
          @activities = Activity.select(:id, :activity_name, :unit, :theme_name)
                               .where(department_id: @user_detail.department_id)
          render :edit
        end
      end
    rescue => e
      Rails.logger.error "Error in update action: #{e.message}"

      # Clear any existing flash messages
      flash.clear

      # Redirect based on user role for errors too
      if current_user.hod?
        redirect_to new_user_detail_path,
                    alert: "An error occurred while updating the target."
      else
        redirect_to user_details_path,
                    alert: "An error occurred while updating the target."
      end
    end
  end


  def update_quarterly_achievements
    # Get the correct parameters
    selected_quarter = params[:selected_quarter]
    selected_department = params[:selected_department] # NEW: Get selected department
    achievement_data = params[:achievements] || {}
    success_count = 0
    errors = []
    updated_activities = []

    Rails.logger.info "Quarterly update params: selected_quarter=#{selected_quarter}, selected_department=#{selected_department}, achievements=#{achievement_data.inspect}"
    Rails.logger.info "All params received: #{params.inspect}"
    Rails.logger.info "Achievement data keys: #{achievement_data.keys}"
    Rails.logger.info "Department filter applied: #{selected_department.present? ? 'YES - ' + selected_department : 'NO - All departments'}"
    Rails.logger.info "=== DEPARTMENT-SPECIFIC EDITING DEBUG ==="
    Rails.logger.info "Selected department: #{selected_department.inspect}"
    Rails.logger.info "Will only process department: #{selected_department.present? ? selected_department : 'ALL DEPARTMENTS'}"

    if achievement_data.empty?
      flash[:alert] = "No achievement data received. Please try again."
      redirect_to quarterly_edit_all_user_details_path(quarter: selected_quarter)
      return
    end

    # Define quarter months to limit updates to selected quarter only
    quarter_months = case selected_quarter
    when "Q1"
      [ "q1" ]  # Quarterly data is stored as q1, q2, q3, q4
    when "Q2"
      [ "q2" ]
    when "Q3"
      [ "q3" ]
    when "Q4"
      [ "q4" ]
    else
      [ "q1", "q2", "q3", "q4" ]  # If no quarter selected, allow all quarters
    end

    # Track which departments had changes to reset their quarter only
    departments_with_changes = Set.new
    employee_details_with_changes = Set.new

    ActiveRecord::Base.transaction do
      Rails.logger.info "Processing #{achievement_data.keys.count} user details"

      achievement_data.each do |user_detail_id, monthly_data|
        Rails.logger.info "Processing user_detail_id: #{user_detail_id}, monthly_data: #{monthly_data.inspect}"

        user_detail = UserDetail.find_by(id: user_detail_id)
        if user_detail.nil?
          Rails.logger.error "UserDetail not found for ID: #{user_detail_id}"
          next
        end

        # FIXED: If a specific department is selected, only process that department
        if selected_department.present?
          next unless user_detail.department.department_type == selected_department
          Rails.logger.info "Processing only #{selected_department} department for user_detail_id: #{user_detail_id}"
        end

        activity_updated = false
        department_has_changes = false

        monthly_data.each do |quarter, values|
          Rails.logger.info "Processing quarter: #{quarter}, values: #{values.inspect}"
          # IMPORTANT: Only process quarters that belong to the selected quarter
          next unless quarter_months.include?(quarter)

          achievement_value = values[:achievement]
          employee_remarks = values[:employee_remarks]

          # Skip if both achievement and remarks are blank
          next if achievement_value.blank? && employee_remarks.blank?

          # FIXED: Store quarterly data directly (q1, q2, q3, q4) instead of monthly data
          # This matches what the ERB template expects
          actual_quarter = quarter  # Use the quarter name directly (q1, q2, q3, q4)

          # Clear any existing monthly achievements for this quarter to avoid conflicts
          # (april, may, june for q1, etc.)
          case actual_quarter
          when "q1"
            user_detail.achievements.where(month: [ "april", "may", "june" ]).destroy_all
          when "q2"
            user_detail.achievements.where(month: [ "july", "august", "september" ]).destroy_all
          when "q3"
            user_detail.achievements.where(month: [ "october", "november", "december" ]).destroy_all
          when "q4"
            user_detail.achievements.where(month: [ "january", "february", "march" ]).destroy_all
          end

          # Find or initialize achievement for the quarter
          achievement = Achievement.find_or_initialize_by(
            user_detail: user_detail,
            month: actual_quarter
          )

            # Store old values for comparison
            old_achievement = achievement.achievement
            old_remarks = achievement.employee_remarks

            # Update values
            achievement.achievement = achievement_value.present? ? achievement_value : nil
            achievement.employee_remarks = employee_remarks.present? ? employee_remarks : nil

            # Check if there are actual changes (including nil to empty string changes)
            achievement_changed = (achievement.achievement != old_achievement) ||
                                 (achievement.employee_remarks != old_remarks)

            # Also check if we have any non-blank values to save
            has_values = achievement.achievement.present? || achievement.employee_remarks.present?

            Rails.logger.info "Achievement change check: quarter=#{quarter}, user_detail_id=#{user_detail_id}, achievement_changed=#{achievement_changed}, has_values=#{has_values}, old_achievement=#{old_achievement}, new_achievement=#{achievement.achievement}"

            # Save if there are changes or if we have values to save
            if achievement_changed || has_values
              if achievement.save
                success_count += 1
                activity_updated = true
                department_has_changes = true
                Rails.logger.info "Successfully saved achievement for #{quarter}: #{achievement.achievement}"
              else
                error_msg = "Failed to save #{quarter.upcase} for #{user_detail.activity.activity_name}: #{achievement.errors.full_messages.join(', ')}"
                errors << error_msg
                Rails.logger.error "Failed to save achievement: #{error_msg}"
              end
            else
              Rails.logger.info "No changes detected for #{quarter} - skipping save"
            end
        end

        if activity_updated
          activity_name = "#{user_detail.employee_detail&.employee_name} - #{user_detail.activity.activity_name}"
          updated_activities << activity_name
        end

        # FIXED: Only mark department as having changes if it actually has changes
        if department_has_changes
          employee_details_with_changes.add(user_detail.employee_detail_id)
          departments_with_changes.add(user_detail.department_id)
          Rails.logger.info "Department #{user_detail.department.department_type} marked as having changes"
        end
      end

      # FIXED: Only set achievements to pending for departments that actually had changes
      # This ensures that only the specific departments that were edited get reset to pending
      # NEW: If a specific department is selected, only process that department
      departments_to_process = if selected_department.present?
        # Find the department by name and only process it if it had changes
        department = Department.find_by(department_type: selected_department)
        Rails.logger.info "Looking for department: #{selected_department}, found: #{department ? department.id : 'NOT FOUND'}"
        Rails.logger.info "Departments with changes: #{departments_with_changes.to_a}"

        if department && departments_with_changes.include?(department.id)
          Rails.logger.info "Processing ONLY department: #{selected_department} (ID: #{department.id})"
          [ department.id ]
        else
          Rails.logger.info "Department #{selected_department} not found or had no changes - no departments to process"
          []
        end
      else
        # If no specific department selected, process all departments with changes
        Rails.logger.info "No department filter - processing all departments with changes: #{departments_with_changes.to_a}"
        departments_with_changes.to_a
      end

      departments_to_process.each do |department_id|
        department = Department.find(department_id)
        Rails.logger.info "Setting quarter #{selected_quarter} to pending for department: #{department.department_type}"

        # Get all achievements for this specific department in the selected quarter
        # Map quarter to actual month names for status reset
        quarter_months_for_reset = case selected_quarter
        when "Q1"
          [ "april", "may", "june" ]  # Q1 = Apr-May-Jun
        when "Q2"
          [ "july", "august", "september" ]  # Q2 = Jul-Aug-Sep
        when "Q3"
          [ "october", "november", "december" ]  # Q3 = Oct-Nov-Dec
        when "Q4"
          [ "january", "february", "march" ]  # Q4 = Jan-Feb-Mar
        else
          quarter_months
        end

        # FIXED: Only reset achievements for the specific department that was edited
        # Get all achievements for this department in the selected quarter
        department_achievements = Achievement.joins(:user_detail)
                                           .where(user_details: { department_id: department_id })
                                           .where(month: quarter_months_for_reset)

        # Set status to pending for this department's achievements only
        updated_count = department_achievements.update_all(status: "pending")
        Rails.logger.info "Updated #{updated_count} achievements to pending status for department #{department.department_type} ONLY"

        # FIXED: Don't update EmployeeDetail status - let each department manage its own status
        # The L1 view now calculates status based on department-specific achievements
        Rails.logger.info "Department #{department.department_type} achievements reset to pending - EmployeeDetail status unchanged for department-wise management"

        # Also reset approval remarks for this department's achievements
        department_achievements.joins(:achievement_remark).each do |achievement|
          achievement.achievement_remark.update(
            l1_remarks: nil,
            l1_percentage: nil,
            l2_remarks: nil,
            l2_percentage: nil,
            l3_remarks: nil,
            l3_percentage: nil
          )
        end

        Rails.logger.info "Reset approval remarks for department #{department.department_type} in quarter #{selected_quarter}"
      end
    end

    # Handle response messages
    if errors.empty?
      if success_count > 0
        # NEW: Show department-specific message
        if selected_department.present?
          flash[:notice] = "✅ Updated Successfully - Only #{selected_department} department set to pending for #{selected_quarter}. #{success_count} achievements updated."
        else
          affected_departments = departments_with_changes.map do |dept_id|
            Department.find(dept_id).department_type
          end.join(", ")
          flash[:notice] = "✅ Updated Successfully - Only #{affected_departments} department(s) set to pending for #{selected_quarter}. #{success_count} achievements updated."
        end

        # Redirect to refresh the page and show updated values
        # Add multiple cache-busting parameters to ensure fresh data
        redirect_params = {
          quarter: selected_quarter,
          department: selected_department,
          t: Time.current.to_i,
          refresh: Time.current.to_f,
          cache_bust: rand(1000000),
          updated: "true",
          timestamp: Time.current.to_i
        }
        # Redirect to submitted view data page to show updated values with aggressive cache busting
        redirect_params.merge!({
          force_refresh: "true",
          data_updated: "true",
          timestamp: Time.current.to_i,
          cache_bust: rand(1000000)
        })
        redirect_to submitted_view_data_path(redirect_params)
        return
      else
        flash[:notice] = "No changes were made to the achievements."
      end
    else
      flash[:alert] = "⚠️ Some updates failed: #{errors.first(2).join('; ')}"
      flash[:alert] += " and #{errors.count - 2} more errors..." if errors.count > 2
    end

    redirect_to quarterly_edit_all_user_details_path(quarter: selected_quarter)

    rescue => e
      Rails.logger.error "Quarterly update error: #{e.message}\n#{e.backtrace.join("\n")}"
      flash[:alert] = "❌ An error occurred while updating achievements: #{e.message}"
      redirect_to quarterly_edit_all_user_details_path(quarter: selected_quarter)
  end

  # FIXED: Quarterly edit all method - now department-specific
  def quarterly_edit_all
    # Get the selected quarter from parameters
    @selected_quarter = params[:quarter] || ""
    # Get the selected department from parameters (NEW)
    @selected_department = params[:department] || ""

    if current_user.role == "employee" || current_user.role == "l1_employer" || current_user.role == "l2_employer"
      # FIXED: Find ALL employee details for this user (not just one)
      # A user can have multiple employee detail records for different departments
      employee_details = EmployeeDetail.where(employee_email: current_user.email)

      # If no results found with email, try with employee_code
      if employee_details.empty? && current_user.employee_code.present?
        employee_details = EmployeeDetail.where(employee_code: current_user.employee_code)
      end

      @user_details = if employee_details.any?
        # Get user details from ALL employee details that match this user
        # This ensures we show data from ALL departments the user belongs to
        employee_detail_ids = employee_details.pluck(:id)

        # FIXED: Deduplicate by activity and department to avoid showing duplicate entries
        # when user has multiple employee_detail records for the same activities
        # Use a subquery to get the minimum ID for each activity-department combination
        min_ids = UserDetail.where(employee_detail_id: employee_detail_ids)
                           .group(:activity_id, :department_id)
                           .minimum(:id)

        # FIXED: Filter by department if specified and reload fresh data
        user_details_query = UserDetail.includes(:department, :activity, :employee_detail, achievements: :achievement_remark)
                                      .where(id: min_ids.values)

        if @selected_department.present?
          user_details_query = user_details_query.joins(:department)
                                                .where(departments: { department_type: @selected_department })
        end

        # FIXED: Order by department and activity names and reload fresh achievements
        user_details = user_details_query.order("departments.department_type, activities.activity_name")

        # Force a fresh database query to ensure we get the latest data
        # This is especially important after updates
        if params[:updated] == "true" || params[:refresh].present?
          Rails.logger.info "Forcing fresh database query due to update/refresh parameters"
          # Re-query the database to get fresh data
          fresh_user_detail_ids = user_details.pluck(:id)
          user_details = UserDetail.includes(:department, :activity, :employee_detail, achievements: :achievement_remark)
                                  .where(id: fresh_user_detail_ids)
                                  .order("departments.department_type, activities.activity_name")
        end

        # Force reload achievements to get fresh data from database
        # Clear all cached associations first
        user_details.each do |user_detail|
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

        user_details
      else
        UserDetail.none
      end
    elsif current_user.role == "hod"
      @user_details = UserDetail.includes(:department, :activity, :employee_detail, achievements: :achievement_remark)
                              .order("departments.department_type, employee_details.employee_name, activities.activity_name")
    else
      @user_details = UserDetail.none
    end


    # FIXED: Correct quarter definitions to match the system
    @quarters = [
      { name: "Q1", months: [ "april", "may", "june" ], label: "Q1 (Apr-Jun)" },
      { name: "Q2", months: [ "july", "august", "september" ], label: "Q2 (Jul-Sep)" },
      { name: "Q3", months: [ "october", "november", "december" ], label: "Q3 (Oct-Dec)" },
      { name: "Q4", months: [ "january", "february", "march" ], label: "Q4 (Jan-Mar)" }
    ]
  end


  def destroy
    begin
      @user_detail = UserDetail.find(params[:id])

      # Store the current context before deletion
      department_id = @user_detail.department_id
      employee_detail_id = @user_detail.employee_detail_id

      if @user_detail.destroy
        # Clear any existing flash messages
        flash.clear

        # Redirect based on user role
        if current_user.hod?
          redirect_to new_user_detail_path,
                      notice: "Target was successfully deleted."
        else
          redirect_to user_details_path,
                      notice: "Target was successfully deleted."
        end
      else
        # Clear any existing flash messages
        flash.clear

        # Redirect based on user role for errors
        if current_user.hod?
          redirect_to new_user_detail_path,
                      alert: "Failed to delete target."
        else
          redirect_to user_details_path,
                      alert: "Failed to delete target."
        end
      end
    rescue ActiveRecord::RecordNotFound
      # Clear any existing flash messages
      flash.clear

      # Redirect based on user role for errors
      if current_user.hod?
        redirect_to new_user_detail_path,
                    alert: "Target not found."
      else
        redirect_to user_details_path,
                    alert: "Target not found."
      end
    rescue => e
      Rails.logger.error "Error in destroy action: #{e.message}"

      # Clear any existing flash messages
      flash.clear

      # Redirect based on user role for errors
      if current_user.hod?
        redirect_to new_user_detail_path,
                    alert: "An error occurred while deleting the target."
      else
        redirect_to user_details_path,
                    alert: "An error occurred while deleting the target."
      end
    end
  end

  def test_sms
    # Test SMS functionality directly
    begin
      # Find a real employee detail record that has L1 code and mobile number
      test_employee = EmployeeDetail.joins(:user_detail)
                                   .where.not(l1_code: [ nil, "" ])
                                   .where.not(mobile_number: [ nil, "" ])
                                   .first

      if test_employee.nil?
        flash[:alert] = "❌ No employee found with L1 code and mobile number for testing"
        redirect_to get_user_detail_user_details_path
        return
      end

      # Find the L1 manager
      l1_manager = EmployeeDetail.find_by("employee_code LIKE ?", test_employee.l1_code.to_s.strip + "%")

      if l1_manager.nil?
        flash[:alert] = "❌ L1 manager not found with code: #{test_employee.l1_code}"
        redirect_to get_user_detail_user_details_path
        return
      end

      if l1_manager.mobile_number.blank?
        flash[:alert] = "❌ L1 manager #{l1_manager.employee_name} has no mobile number"
        redirect_to get_user_detail_user_details_path
        return
      end

      # Test with Q1 quarter
      result = send_sms_to_l1(test_employee, "Q1 (APR-JUN)", nil)

      if result[:success]
        flash[:notice] = "✅ Test SMS sent successfully! Message ID: #{result[:message_id]}"
      else
        flash[:alert] = "❌ Test SMS failed: #{result[:error]}"
        Rails.logger.error "Test SMS failed: #{result.inspect}"
      end

    rescue => e
      flash[:alert] = "❌ Test SMS error: #{e.message}"
      Rails.logger.error "Test SMS error: #{e.message}\n#{e.backtrace.first(5).join("\n")}"
    end

    redirect_to get_user_detail_user_details_path
  end

  def test_email
    # Test email functionality directly
    begin
      # Use test email address
      test_email = "av.anamika1@gmail.com"

      # Find a real employee detail record
      test_employee = EmployeeDetail.joins(:user_details).first

      if test_employee.nil?
        flash[:alert] = "❌ No employee found for email testing"
        redirect_to get_user_detail_user_details_path
        return
      end

      test_user_detail = test_employee.user_details.first

      if test_user_detail.nil?
        flash[:alert] = "❌ No user detail found for email testing"
        redirect_to get_user_detail_user_details_path
        return
      end

      # Find or create a test achievement
      test_achievement = test_user_detail.achievements.first ||
                        test_user_detail.achievements.create!(
                          month: "april",
                          achievement: "Test achievement for email functionality",
                          status: "pending"
                        )

      # Test L1 approval request email
      ApprovalMailer.l1_approval_request(test_achievement, test_email).deliver_now

      flash[:notice] = "✅ Test email sent successfully to #{test_email}! Check inbox and Rails logs."

    rescue => e
      flash[:alert] = "❌ Test email error: #{e.message}"
      Rails.logger.error "Test email error: #{e.message}\n#{e.backtrace.first(5).join("\n")}"
    end

    redirect_to get_user_detail_user_details_path
  end

  def get_user_detail
    if [ "employee", "l1_employer", "l2_employer" ].include?(current_user.role)
      # FIXED: Find ALL employee details for this user (not just one)
      # A user can have multiple employee detail records for different departments
      @employee_details = EmployeeDetail.where(employee_email: current_user.email)

      # If no results found with email, try with employee_code
      if @employee_details.empty? && current_user.employee_code.present?
        @employee_details = EmployeeDetail.where(employee_code: current_user.employee_code)
      end

      @employee_detail = @employee_details.first # Keep for backward compatibility

      @user_details = if @employee_details.any?
        # FIXED: Show data for the CURRENT USER only, not all employees
        # Filter by the current user's employee details only
        employee_detail_ids = @employee_details.pluck(:id)

        # FIXED: Deduplicate by activity and department to avoid showing duplicate entries
        # when user has multiple employee_detail records for the same activities
        # Use a subquery to get the minimum ID for each activity-department combination
        min_ids = UserDetail.where(employee_detail_id: employee_detail_ids)
                           .group(:activity_id, :department_id)
                           .minimum(:id)

        UserDetail.includes(:department, :activity, :employee_detail, achievements: :achievement_remark)
                  .where(id: min_ids.values)
                  .order("departments.department_type, activities.activity_name")
                  .limit(100)
      else
        UserDetail.none
      end

      # Get user's actual departments dynamically from ALL their user details
      @user_departments = if @employee_details.any?
        @user_details.includes(:department).map(&:department).uniq.compact
      else
        []
      end

    elsif current_user.role == "hod"
      @user_details = UserDetail.includes(:department, :activity, :employee_detail, achievements: :achievement_remark)
                                .order("departments.department_type, employee_details.employee_name, activities.activity_name")
                                .limit(100)
      @employee_detail = nil
      @employee_details = []

      # HOD sees all departments
      @user_departments = Department.select("DISTINCT department_type").pluck(:department_type).compact.map do |dept_type|
        OpenStruct.new(department_type: dept_type)
      end
    end
  end

  def submit_achievements
    begin
      achievement_data = params[:achievement] || {}
      success_count = 0
      sms_results = []
      email_results = []
      processed_employees = Set.new

      Rails.logger.info "Starting achievement submission with data: #{achievement_data.inspect}"
      Rails.logger.info "Request format: #{request.format}"
      Rails.logger.info "Request headers: #{request.headers.to_h.select { |k, v| k.include?('Content-Type') || k.include?('Accept') }}"

      ActiveRecord::Base.transaction do
        Rails.logger.info "Database transaction started"

        achievement_data.each do |user_detail_id, monthly_data|
          user_detail = UserDetail.find_by(id: user_detail_id)
          next unless user_detail

          employee_detail = user_detail.employee_detail
          next unless employee_detail

          monthly_data.each do |month, values|
            achievement_value = values[:achievement]
            employee_remarks = values[:employee_remarks]

            # Skip if both achievement and remarks are blank
            next if achievement_value.blank? && employee_remarks.blank?

            target_value = user_detail.send(month)
            # For quarterly submissions (q1, q2, q3, q4), allow creation even if target_value is blank
            # For monthly submissions, still require target_value to be present
            if month.match?(/^q[1-4]$/)
              Rails.logger.info "Processing quarterly submission for #{month}: target_value=#{target_value || 'nil'}"
            else
              next if target_value.blank?
            end

            Rails.logger.info "Processing month #{month}: achievement=#{achievement_value}, remarks=#{employee_remarks}"

            achievement = Achievement.find_or_initialize_by(
              user_detail: user_detail,
              month: month
            )

            achievement.achievement = achievement_value
            achievement.employee_remarks = employee_remarks
            achievement.status = "pending"

            if achievement.save
              success_count += 1
              Rails.logger.info "Achievement saved for #{month}: #{achievement.achievement}"
            else
              Rails.logger.error "Failed to save achievement for #{month}: #{achievement.errors.full_messages}"
            end
          end

          # Send SMS only once per employee per quarter
          unless processed_employees.include?(employee_detail.id)
            processed_employees.add(employee_detail.id)

            quarters_filled = Set.new
            monthly_data.each do |month, values|
              next if values[:achievement].blank?
              quarter = determine_quarter(month)
              quarters_filled.add(quarter) if quarter.present?
            end

            quarters_filled.each do |quarter|
              Rails.logger.info "Processing quarter: #{quarter} for employee: #{employee_detail.employee_name}"

              sms_already_sent = check_sms_already_sent(employee_detail.id, quarter)

              if sms_already_sent
                sms_results << {
                  quarter: quarter,
                  employee: employee_detail.employee_name,
                  success: false,
                  message: "SMS already sent for this quarter"
                }
              else
                sms_result = send_sms_to_l1_new(employee_detail, quarter, user_detail)
                sms_results << {
                  quarter: quarter,
                  employee: employee_detail.employee_name,
                  success: sms_result[:success],
                  message: sms_result[:success] ? "SMS sent successfully" : sms_result[:error]
                }

                # Only mark as sent if SMS was actually successful
                if sms_result[:success]
                  mark_sms_as_sent(employee_detail.id, quarter)
                end
              end

              # Send email notification to L1 for quarterly submission
              Rails.logger.info "About to send email for quarter: #{quarter}, user_detail_id: #{user_detail.id}"
              email_result = send_quarterly_l1_email(employee_detail, quarter, user_detail)
              email_results << {
                quarter: quarter,
                employee: employee_detail.employee_name,
                success: email_result[:success],
                message: email_result[:message]
              }

              # Send email notification to employee for quarterly submission confirmation
              employee_email_result = send_quarterly_submission_confirmation_email(employee_detail, quarter, user_detail)
              email_results << {
                quarter: quarter,
                employee: employee_detail.employee_name,
                success: employee_email_result[:success],
                message: employee_email_result[:message]
              }
            end
          end
        end

        Rails.logger.info "Database transaction completed successfully"
      end

      # Prepare response message with more details
      response_message = "🎉 Achievements submitted successfully! #{success_count} records updated."

      # Add SMS results
      if sms_results.any?
        successful_sms = sms_results.select { |r| r[:success] }
        failed_sms = sms_results.select { |r| !r[:success] }

        if successful_sms.any?
          response_message += " 📱 SMS notifications sent to managers for #{successful_sms.count} quarter(s)."
        end

        if failed_sms.any?
          response_message += " ⚠️ #{failed_sms.count} SMS failed to send. Check SMS logs for details."
        end
      else
        response_message += " ℹ️ No SMS sent (already sent for this quarter or missing L1/L2 codes)."
      end

      # Add email results
      if email_results.any?
        successful_emails = email_results.select { |r| r[:success] }
        failed_emails = email_results.select { |r| !r[:success] }

        if successful_emails.any?
          response_message += " 📧 Email notifications sent to managers for #{successful_emails.count} quarter(s)."
        end

        if failed_emails.any?
          response_message += " ⚠️ #{failed_emails.count} emails failed to send. Check logs for details."
        end
      else
        response_message += " ℹ️ No emails sent (no pending achievements or missing L1 email)."
      end

      # Add final success note
      response_message += " Your data has been saved and is ready for manager review."

      Rails.logger.info "Achievement submission successful. Count: #{success_count}, Message: #{response_message}"

      render json: {
        success: true,
        count: success_count,
        sms_results: sms_results,
        email_results: email_results,
        message: response_message
      }
    rescue => e
      Rails.logger.error "Achievement submission failed: #{e.message}"
      Rails.logger.error "Error class: #{e.class}"
      Rails.logger.error "Backtrace: #{e.backtrace.first(10).join("\n")}"

      error_response = {
        success: false,
        error: "Achievement submission failed: #{e.message}",
        message: "There was an error submitting achievements. Please try again."
      }

      Rails.logger.error "Error response prepared: #{error_response.inspect}"

      render json: error_response, status: :internal_server_error
    end
  end

  def get_activities
    department_id = params[:department_id]

    if department_id.present?
      activities = Activity.select(:id, :activity_name, :unit, :weight, :theme_name)
                          .where(department_id: department_id)

      activities_data = activities.map do |activity|
        {
          id: activity.id,
          activity_name: activity.activity_name,
          unit: activity.unit,
          weight: activity.weight,
          theme_name: activity.theme_name
        }
      end

      render json: activities_data
    else
      render json: { error: "Department ID is required" }, status: :bad_request
    end
  rescue ActiveRecord::RecordNotFound
    render json: { error: "Department not found" }, status: :not_found
  rescue => e
    render json: { error: "An error occurred while fetching activities" }, status: :internal_server_error
  end

  def bulk_create
    department_id = params[:department_id]
    employee_detail_id = params[:employee_detail_id]
    user_details_params = params[:user_details]

    # Enhanced validation
    if department_id.blank?
      render json: { error: "Department ID is required" }, status: :bad_request
      return
    end

    if employee_detail_id.blank?
      render json: { error: "Employee Detail ID is required" }, status: :bad_request
      return
    end

    if user_details_params.blank?
      render json: { error: "No user details provided" }, status: :bad_request
      return
    end

    # Validate that department and employee exist
    unless Department.exists?(department_id)
      render json: { error: "Department not found" }, status: :not_found
      return
    end

    unless EmployeeDetail.exists?(employee_detail_id)
      render json: { error: "Employee not found" }, status: :not_found
      return
    end

    created_count = 0
    updated_count = 0
    errors = []

    # Bulk operations for better performance
    activity_ids = user_details_params.keys
    existing_records = UserDetail.where(
      department_id: department_id,
      activity_id: activity_ids,
      employee_detail_id: employee_detail_id
    ).index_by { |record| "#{record.department_id}_#{record.activity_id}_#{record.employee_detail_id}" }

    ActiveRecord::Base.transaction do
      user_details_params.each do |activity_id, details|
        begin
          unless Activity.exists?(activity_id)
            errors << "Activity with ID #{activity_id} not found"
            next
          end

          # Extract quarterly data
          quarterly_data = {
            q1: extract_month_value(details, "q1"),
            q2: extract_month_value(details, "q2"),
            q3: extract_month_value(details, "q3"),
            q4: extract_month_value(details, "q4")
          }

          # Extract activity metadata (unit, theme_name, and weight)
          # Handle blank values properly - convert empty strings to nil for database
          unit_value = details["unit"] || details[:unit]
          theme_value = details["theme_name"] || details[:theme_name]
          weight_value = details["weight"] || details[:weight]

          activity_metadata = {
            unit: unit_value.present? ? unit_value : nil,
            theme_name: theme_value.present? ? theme_value : nil,
            weight: weight_value.present? ? weight_value.to_f : nil
          }

          existing_record = existing_records["#{department_id}_#{activity_id}_#{employee_detail_id}"]

          # Update Activity metadata (always update to handle clearing values)
          activity = Activity.find(activity_id)
          activity_update_data = {}

          # Always include unit, theme_name, and weight in update (nil values will clear the fields)
          activity_update_data[:unit] = activity_metadata[:unit]
          activity_update_data[:theme_name] = activity_metadata[:theme_name]
          activity_update_data[:weight] = activity_metadata[:weight]

          unless activity.update(activity_update_data)
            errors << "Failed to update activity metadata for activity #{activity_id}: #{activity.errors.full_messages.join(', ')}"
          end

          # Process quarterly achievements
          process_quarterly_achievements(department_id, activity_id, employee_detail_id, details)

          if existing_record
            if existing_record.update(quarterly_data)
              updated_count += 1
            else
              errors << "Failed to update activity #{activity_id}: #{existing_record.errors.full_messages.join(', ')}"
            end
          else
            # Additional safety check to prevent duplicates
            existing_check = UserDetail.find_by(
              department_id: department_id,
              activity_id: activity_id,
              employee_detail_id: employee_detail_id
            )

            if existing_check
              # If a record exists but wasn't found in our initial query, update it instead
              if existing_check.update(quarterly_data)
                updated_count += 1
              else
                errors << "Failed to update existing activity #{activity_id}: #{existing_check.errors.full_messages.join(', ')}"
              end
            else
              new_record = UserDetail.new(
                department_id: department_id,
                activity_id: activity_id,
                employee_detail_id: employee_detail_id,
                **quarterly_data
              )

              if new_record.save
                created_count += 1
              else
                errors << "Failed to create activity #{activity_id}: #{new_record.errors.full_messages.join(', ')}"
              end
            end
          end
        rescue => e
          errors << "Error processing activity #{activity_id}: #{e.message}"
        end
      end

      if errors.present? && (created_count + updated_count) == 0
        raise ActiveRecord::Rollback
      end
    end

    if errors.empty? || (created_count + updated_count) > 0
      message = []
      message << "#{created_count} records created" if created_count > 0
      message << "#{updated_count} records updated" if updated_count > 0
      message = [ "No changes made" ] if message.empty?

      response_data = {
        success: true,
        message: message.join(", "),
        created: created_count,
        updated: updated_count
      }

      response_data[:warnings] = errors if errors.present?

      render json: response_data
    else
      render json: {
        success: false,
        error: "Failed to save records",
        errors: errors,
        created: created_count,
        updated: updated_count
      }, status: :unprocessable_entity
    end
  end

  def export
    @user_details = UserDetail.includes(:employee_detail, :department, :activity)
                              .limit(5000)

    respond_to do |format|
      format.xlsx {
        response.headers["Content-Disposition"] = 'attachment; filename="user_details.xlsx"'
      }
    end
  end

  def import
    file = params[:file]

    unless file && [ ".xlsx", ".xls" ].include?(File.extname(file.original_filename))
      redirect_to new_user_detail_path, alert: "Please upload a valid .xlsx or .xls file."
      return
    end

    begin
      spreadsheet = Roo::Excelx.new(file.tempfile.path)
      header = spreadsheet.row(1)



      errors = []
      success_count = 0
      user_accounts_created = 0
      user_accounts_updated = 0
      batch_size = 100

      # Build cache of existing users ONCE for entire import (much faster for 1000+ users)
      Rails.logger.info "Building cache of existing users for bulk import..."
      existing_users_cache = UserCreationService.build_existing_users_cache
      Rails.logger.info "Loaded #{existing_users_cache[:by_email].size} existing users by email, #{existing_users_cache[:by_code].size} by employee_code"

      # Process in batches for better performance
      (2..spreadsheet.last_row).each_slice(batch_size) do |rows|
        ActiveRecord::Base.transaction do
          rows.each do |i|
            row_data = spreadsheet.row(i)
            row = {}
            header.each_with_index do |col_name, index|
              next if col_name.nil?
              key = col_name.to_s.strip.downcase.gsub(/\s+/, "_")
              row[key] = row_data[index]
            end



            # Extract the 15 columns including Employee Email, Employee Code, and L1/L2/L3 codes
            department_type = row["department"]
            employee_name = row["employee_name"]
            employee_email = row["employee_email"]
            employee_code = row["employee_code"]
            mobile_number = row["mobile_number"] || row["mobile_no"] || row["mobile"]
            l1_code = row["l1_code"]
            l1_employer_name = row["l1_employer"]
            l2_code = row["l2_code"]
            l2_employer_name = row["l2_employer"]
            l3_code = row["l3_code"]
            l3_employer_name = row["l3_employer"]
            activity_name = row["activity"]
            activity_theme_name = row["theme"]
            unit = row["unit"]
            weightage = row["weightage"] || row["weight"]

            # Debug logging for weight values
            Rails.logger.info "Processing weight for row #{i}: original_weightage=#{row['weightage']}, original_weight=#{row['weight']}, final_weightage=#{weightage}"






            if employee_name.blank?
              errors << "Row #{i}: Employee name is missing"
              next
            end

            if department_type.blank?
              errors << "Row #{i}: Department is missing"
              next
            end

            if activity_name.blank?
              errors << "Row #{i}: Activity name is missing"
              next
            end

            department = Department.find_or_create_by!(department_type: department_type)

            # Create/update employee with all required fields including email, code, and L1/L2/L3 codes
            employee = EmployeeDetail.find_or_create_by!(
              employee_name: employee_name.to_s.strip,
              department: department_type.to_s.strip
            ) do |e|
              e.employee_email = employee_email.to_s.strip if employee_email.present?
              e.employee_code = employee_code.to_s.strip if employee_code.present?
              e.mobile_number = mobile_number.to_s.strip if mobile_number.present?
              e.l1_code = l1_code.to_s.strip if l1_code.present?
              e.l1_employer_name = l1_employer_name.to_s.strip if l1_employer_name.present?
              e.l2_code = l2_code.to_s.strip if l2_code.present?
              e.l2_employer_name = l2_employer_name.to_s.strip if l2_employer_name.present?
              e.l3_code = l3_code.to_s.strip if l3_code.present?
              e.l3_employer_name = l3_employer_name.to_s.strip if l3_employer_name.present?
            end

            # Update fields if they exist in Excel
            update_fields = {}
            update_fields[:employee_email] = employee_email.to_s.strip if employee_email.present?
            update_fields[:employee_code] = employee_code.to_s.strip if employee_code.present?
            update_fields[:mobile_number] = mobile_number.to_s.strip if mobile_number.present?
            update_fields[:l1_code] = l1_code.to_s.strip if l1_code.present?
            update_fields[:l1_employer_name] = l1_employer_name.to_s.strip if l1_employer_name.present?
            update_fields[:l2_code] = l2_code.to_s.strip if l2_code.present?
            update_fields[:l2_employer_name] = l2_employer_name.to_s.strip if l2_employer_name.present?
            update_fields[:l3_code] = l3_code.to_s.strip if l3_code.present?
            update_fields[:l3_employer_name] = l3_employer_name.to_s.strip if l3_employer_name.present?

            employee.update!(update_fields) if update_fields.any?

            # Create user account for the employee if both email AND employee_code are present
            # This ensures accounts are created only when complete data is available
            # Using existing_users_cache for faster lookups (optimized for bulk imports)
            if employee.employee_email.present? && employee.employee_code.present?
              user_creation_result = UserCreationService.create_user_from_employee_data({
                employee_email: employee.employee_email,
                employee_code: employee.employee_code,
                employee_name: employee.employee_name
              }, existing_users_cache)

              if user_creation_result[:success]
                if user_creation_result[:message].include?("created successfully")
                  user_accounts_created += 1
                elsif user_creation_result[:message].include?("already exists")
                  user_accounts_updated += 1
                end
                # Reduced logging for bulk operations - only log every 100th user or errors
                Rails.logger.info "User creation result for #{employee.employee_name}: #{user_creation_result[:message]}" if i % 100 == 0
              else
                Rails.logger.warn "Failed to create user account for #{employee.employee_name}: #{user_creation_result[:message]}"
              end
            end

            # FIXED: Handle weightage values correctly - convert percentage strings to proper values
            processed_weightage = if weightage.present?
              weightage_str = weightage.to_s.strip
              if weightage_str.include?("%")
                # If it contains %, remove the % and use the number as-is
                weightage_str.gsub("%", "").to_f
              elsif weightage_str.to_f < 1 && weightage_str.to_f > 0
                # If it's a decimal like 0.1, convert to percentage (0.1 -> 10)
                weightage_str.to_f * 100
              else
                # If it's already a whole number like 10, use as-is
                weightage_str.to_f
              end
            else
              nil
            end

            activity = Activity.find_or_create_by!(
              activity_name: activity_name.to_s.strip,
              department_id: department.id
            ) do |a|
              a.unit = unit.to_s.strip if unit.present?
              a.weight = processed_weightage if processed_weightage.present?
              a.theme_name = activity_theme_name.to_s.strip if activity_theme_name.present?
            end

            # Update activity fields if provided and different
            update_activity_fields = {}
            update_activity_fields[:unit] = unit.to_s.strip if unit.present? && activity.unit != unit.to_s.strip
            update_activity_fields[:weight] = processed_weightage if weightage.present? && activity.weight != processed_weightage
            update_activity_fields[:theme_name] = activity_theme_name.to_s.strip if activity_theme_name.present? && activity.theme_name != activity_theme_name.to_s.strip

            activity.update!(update_activity_fields) if update_activity_fields.any?

            begin
              UserDetail.create!(
                employee_detail_id: employee.id,
                department_id: department.id,
                activity_id: activity.id
              )
              success_count += 1
            rescue ActiveRecord::RecordInvalid => e
              errors << "Row #{i}: #{e.message}"
            end
          end
        end
      end

      # Build success message with user account statistics
      user_account_message = ""
      if user_accounts_created > 0 || user_accounts_updated > 0
        parts = []
        parts << "#{user_accounts_created} accounts created" if user_accounts_created > 0
        parts << "#{user_accounts_updated} accounts updated" if user_accounts_updated > 0
        user_account_message = " #{parts.join(', ')} with default password '123456'."
      end

      if errors.any?
        if success_count > 0
          redirect_to new_user_detail_path, alert: "Partially imported: #{success_count} records saved, but #{errors.count} errors:\n#{errors.first(10).join("\n")}#{user_account_message}"
        else
          redirect_to new_user_detail_path, alert: "Import failed. Errors:\n#{errors.first(10).join("\n")}"
        end
      else
        redirect_to new_user_detail_path, notice: "Excel file imported successfully! #{success_count} records processed.#{user_account_message}"
      end

    rescue => e
      Rails.logger.error "Import error: #{e.message}\n#{e.backtrace.join("\n")}"
      redirect_to new_user_detail_path, alert: "Error reading Excel file: #{e.message}"
    end
  end



  private

  def set_user_detail
    @user_detail = UserDetail.find(params[:id])
  end

  def user_detail_params
    params.require(:user_detail).permit(:department_id, :activity_id, :april, :may, :june,
                                        :july, :august, :september, :october, :november,
                                        :december, :january, :february, :march,
                                        :employee_detail_id, :employee_detail_email,
                                        :activity_theme_name, :activity_unit, :activity_weight)
  end

  def bulk_create_params
    params.permit(:department_id, :employee_detail_id, user_details: {})
  end

  def extract_month_value(details, month)
    return nil if details.blank?

    value = details[month] || details[month.to_sym] || details[month.to_s]

    return nil if value.blank?
    return value.to_f if value.is_a?(String) && value.match?(/^\d+\.?\d*$/)
    value
  end

  def normalize_percentage(value)
    return nil if value.nil?

    # FIXED: Don't convert values to percentages automatically
    # Only convert if explicitly marked as percentage
    if value.is_a?(String)
      # Remove any whitespace
      cleaned_value = value.strip
      return nil if cleaned_value.blank?

      # Handle percentage values (only if they contain % symbol)
      if cleaned_value.include?("%")
        return cleaned_value.gsub("%", "").to_f
      end

      # Handle numeric strings - return as is, don't convert to percentage
      if cleaned_value.match?(/^\d+\.?\d*$/)
        return cleaned_value.to_f
      end

      # Return the original string if it's not numeric
      cleaned_value
    elsif value.is_a?(Numeric)
      # FIXED: Don't automatically convert numbers to percentages
      # Only convert if the value is explicitly a decimal percentage (0.0 to 1.0)
      # AND it's marked as a percentage in the original data
      value
    else
      # For other types, try to convert to string and then process
      normalize_percentage(value.to_s)
    end
  end

  def load_form_data
    @departments = Department.select(:id, :department_type)
    @activities = @user_detail.department_id.present? ?
                  Activity.select(:id, :activity_name, :unit, :theme_name)
                         .where(department_id: @user_detail.department_id) : []
    @user_details = UserDetail.includes(:department, :activity).limit(100)
  end

  def filter_conditions
    conditions = {}

    if params[:department_id].present?
      conditions[:department_id] = params[:department_id]
    end

    if params[:employee_detail_id].present?
      conditions[:employee_detail_id] = params[:employee_detail_id]
    end

    conditions
  end

  # New SMS functionality using SMS service
  def send_sms_to_l1_new(employee_detail, quarter, user_detail)
    begin
      # Find the L1 manager's employee detail record
      l1_code = employee_detail.l1_code
      return { success: false, error: "L1 code not found for employee - SMS not sent" } unless l1_code.present?

      l1_manager = EmployeeDetail.find_by("employee_code LIKE ?", l1_code.to_s.strip + "%")
      return { success: false, error: "L1 manager not found for code: #{l1_code}" } unless l1_manager&.mobile_number.present?

      # Create the SMS message
      message = SmsService.submission_message(employee_detail.employee_name, quarter)

      # Send SMS using the SMS service
      result = SmsService.send_sms(l1_manager.mobile_number, message)

      if result[:success]
        Rails.logger.info "SMS sent successfully to L1 manager #{l1_manager.employee_name} (#{l1_manager.mobile_number}) for employee #{employee_detail.employee_name}"
        { success: true, message: "SMS sent successfully", response: result[:response] }
      else
        Rails.logger.error "SMS failed: #{result[:message]}"
        { success: false, error: result[:message] }
      end

    rescue => e
      Rails.logger.error "SMS service error: #{e.message}"
      Rails.logger.error "Backtrace: #{e.backtrace.first(5).join("\n")}"
      { success: false, error: "SMS service error: #{e.message}" }
    end
  end

  # SMS functionality for quarterly notifications (old method - keeping for reference)
  def send_sms_to_l1(employee_detail, quarter, user_detail)
    begin
      # Only send SMS if employee has both L1 and L2 codes (indicating proper hierarchy)
      l1_code = employee_detail.l1_code
      l2_code = employee_detail.l2_code
      return { success: false, error: "L1 or L2 code not found for employee - SMS not sent" } unless l1_code.present? && l2_code.present?

      # Find the L1 manager's employee detail record
      l1_manager = EmployeeDetail.find_by("employee_code LIKE ?", l1_code.to_s.strip + "%")
      return { success: false, error: "L1 manager not found with code: #{l1_code}" } unless l1_manager.present?

      l1_mobile = l1_manager.mobile_number
      return { success: false, error: "L1 manager mobile number not found" } unless l1_mobile.present?

      # Clean and validate mobile number
      l1_mobile = l1_mobile.to_s.strip.gsub(/\D/, "")
      return { success: false, error: "Invalid mobile number format" } if l1_mobile.length < 10

      # Prepare the message exactly as per the working API example
      message = "Emp-Code: #{employee_detail.employee_code}, Emp-Name: #{employee_detail.employee_name} has submitted his #{quarter} Qtr KRA MIS. Please review and approve in the system. Ploughman Agro Private Limited"

      # Prepare API parameters using the exact working API
      params = {
        authkey: "37317061706c39353312",
        mobiles: l1_mobile,
        message: message,
        sender: "PLOAPL",
        route: "2",
        country: "0",
        DLT_TE_ID: "1707175594432371766",
        unicode: "1"
      }

      # Build the API URL
      api_url = "https://sms.yoursmsbox.com/api/sendhttp.php"

      # Log the API call for debugging
      Rails.logger.info "Sending SMS to L1 manager #{l1_manager.employee_name} (#{l1_mobile}) for employee #{employee_detail.employee_code}"
      Rails.logger.info "SMS API URL: #{api_url}"
      Rails.logger.info "SMS Parameters: #{params.inspect}"

      # Send SMS using HTTParty (which is already in Gemfile)
      require "httparty"
      response = HTTParty.get(api_url, query: params)

      # Log the response for debugging
      Rails.logger.info "SMS API Response Code: #{response.code}"
      Rails.logger.info "SMS API Response Body: #{response.body}"

      if response.success?
        # Parse the JSON response to check if SMS was actually sent
        begin
          response_data = JSON.parse(response.body)
          if response_data["Status"] == "Success" && response_data["Code"] == "000B"
            Rails.logger.info "SMS sent successfully to L1 manager #{l1_manager.employee_name} (#{l1_mobile}) for employee #{employee_detail.employee_code}"
            Rails.logger.info "Message ID: #{response_data['Message-Id']}"
            {
              success: true,
              message: "SMS sent successfully",
              message_id: response_data["Message-Id"],
              response: response_data
            }
          else
            Rails.logger.error "SMS API returned error: #{response_data}"
            {
              success: false,
              error: "SMS API error: #{response_data['Description'] || response_data['Status']}"
            }
          end
        rescue JSON::ParserError => e
          Rails.logger.error "Failed to parse SMS API response: #{e.message}"
          { success: false, error: "Invalid SMS API response format" }
        end
      else
        Rails.logger.error "SMS API HTTP error: #{response.code} - #{response.body}"
        { success: false, error: "SMS API HTTP error: #{response.code}" }
      end

    rescue => e
      Rails.logger.error "SMS service error: #{e.message}"
      Rails.logger.error "Backtrace: #{e.backtrace.first(5).join("\n")}"
      { success: false, error: "SMS service error: #{e.message}" }
    end
  end

  def determine_quarter(month)
    case month.to_s.downcase
    when "april", "may", "june"
      "Q1 (APR-JUN)"
    when "july", "august", "september"
      "Q2 (JUL-SEP)"
    when "october", "november", "december"
      "Q3 (OCT-DEC)"
    when "january", "february", "march"
      "Q4 (JAN-MAR)"
    else
      nil
    end
  end

  def clear_sms_tracking
    # Clear SMS tracking for a fresh start
    # Clear all SMS logs since we're tracking per employee
    SmsLog.destroy_all
    flash[:notice] = "SMS tracking cleared. New SMS will be sent for each quarter."
    redirect_to get_user_detail_user_details_path
  end

  def view_sms_logs
    # View SMS logs to see which SMS have been sent
    @sms_logs = SmsLog.includes(:employee_detail).order(created_at: :desc).limit(50)
    render :view_sms_logs
  end

  def export_excel
    # Only allow Employee and HOD to export excel
    unless current_user.employee? || current_user.hod?
      redirect_to root_path, alert: "You are not authorized to export data."
      return
    end

    begin
      # Use EXACT same logic as get_user_detail method (lines 748-779)
      # This is the proven working code that displays data on the page
      if [ "employee", "l1_employer", "l2_employer" ].include?(current_user.role)
        # Find ALL employee details for this user (not just one)
        employee_details = EmployeeDetail.where(employee_email: current_user.email)

        # If no results found with email, try with employee_code
        if employee_details.empty? && current_user.employee_code.present?
          employee_details = EmployeeDetail.where(employee_code: current_user.employee_code)
        end

        @user_details = if employee_details.any?
          # Show data for the CURRENT USER only, not all employees
          employee_detail_ids = employee_details.pluck(:id)

          # Deduplicate by activity and department
          min_ids = UserDetail.where(employee_detail_id: employee_detail_ids)
                             .group(:activity_id, :department_id)
                             .minimum(:id)

          # EXACT same query as get_user_detail - just removed .limit(100)
          UserDetail.includes(:department, :activity, :employee_detail, achievements: :achievement_remark)
                    .where(id: min_ids.values)
                    .order("departments.department_type, activities.activity_name")
        else
          UserDetail.none
        end

      elsif current_user.role == "hod"
        # For HOD, also filter to show only their own data (not all data)
        employee_details = EmployeeDetail.where(employee_email: current_user.email)

        if employee_details.empty? && current_user.employee_code.present?
          employee_details = EmployeeDetail.where(employee_code: current_user.employee_code)
        end

        @user_details = if employee_details.any?
          employee_detail_ids = employee_details.pluck(:id)
          min_ids = UserDetail.where(employee_detail_id: employee_detail_ids)
                             .group(:activity_id, :department_id)
                             .minimum(:id)

          UserDetail.includes(:department, :activity, :employee_detail, achievements: :achievement_remark)
                    .where(id: min_ids.values)
                    .order("departments.department_type, activities.activity_name")
        else
          UserDetail.none
        end
      else
        @user_details = UserDetail.none
      end

      # Execute the query and convert to array
      @user_details = @user_details.to_a

      Rails.logger.info "Export Excel: Found #{@user_details.count} records for user #{current_user.email} (#{current_user.employee_code}), role: #{current_user.role}"

      respond_to do |format|
        format.xlsx {
          response.headers["Content-Disposition"] = 'attachment; filename="HOD_Target_Form_Export.xlsx"'
        }
      end
    rescue => e
      Rails.logger.error "Export Excel Error: #{e.message}\n#{e.backtrace.join("\n")}"
      redirect_to user_details_path, alert: "❌ Error generating Excel file: #{e.message}"
    end
  end

  def export_department_activity
    # Export department activity data for the data entry form
    begin
      # Get filter parameters
      department_id = params[:department_id]
      employee_detail_id = params[:employee_detail_id]

      # Load data based on filters
      if department_id.present? && employee_detail_id.present?
        # Export specific department and employee data
        @user_details = UserDetail.includes(:department, :activity, :employee_detail)
                                 .where(department_id: department_id, employee_detail_id: employee_detail_id)

        # Get employee and department names for filename
        employee = EmployeeDetail.find_by(id: employee_detail_id)
        department = Department.find_by(id: department_id)
        filename = "Department_Activity_#{department&.department_type}_#{employee&.employee_name}_#{Time.current.strftime('%Y%m%d_%H%M%S')}.xlsx"
      else
        # Export all data if no filters
        @user_details = UserDetail.includes(:department, :activity, :employee_detail).limit(1000)
        filename = "Department_Activity_All_Data_#{Time.current.strftime('%Y%m%d_%H%M%S')}.xlsx"
      end

      # Load departments and activities for the export
      @departments = Department.select("DISTINCT ON (department_type) id, department_type")
      @activities = Activity.includes(:department).order("departments.department_type, activities.activity_name")

      respond_to do |format|
        format.xlsx {
          response.headers["Content-Disposition"] = "attachment; filename=\"#{filename}\""
        }
        format.html {
          redirect_to new_user_detail_path, alert: "Please use the Excel export format."
        }
      end
    rescue => e
      Rails.logger.error "Export Department Activity Error: #{e.message}"
      redirect_to new_user_detail_path, alert: "❌ Error generating Excel file. Please try again."
    end
  end

  def check_sms_already_sent(employee_detail_id, quarter)
    # Check if SMS was already sent for this quarter using database
    # Use employee_detail_id to track per employee, not per activity
    SmsLog.exists?(employee_detail_id: employee_detail_id, quarter: quarter, sent: true)
  end

  def mark_sms_as_sent(employee_detail_id, quarter)
    # Mark SMS as sent in database to prevent duplicates
    # Use employee_detail_id to track per employee, not per activity
    SmsLog.create!(
      employee_detail_id: employee_detail_id,
      quarter: quarter,
      sent: true,
      sent_at: Time.current
    )
  rescue => e
    Rails.logger.error "Failed to mark SMS as sent: #{e.message}"
  end

  def send_quarterly_l1_email(employee_detail, quarter, user_detail)
    # Find L1 user by employee code
    l1_user = User.find_by(employee_code: employee_detail.l1_code)

    # If L1 user not found, try to find L1 manager by employee code in EmployeeDetail
    if l1_user.nil?
      l1_manager = EmployeeDetail.find_by("employee_code LIKE ?", employee_detail.l1_code.to_s.strip + "%")
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
      # Get achievements for the quarter - look for any achievements, not just pending ones
      quarter_months = get_quarter_months_from_quarter_name(quarter)
      Rails.logger.info "Looking for achievements in months: #{quarter_months} for user_detail_id: #{user_detail.id}"

      # Reload user_detail to get fresh achievements from database
      user_detail.reload
      achievements = user_detail.achievements.where(month: quarter_months)

      Rails.logger.info "Found #{achievements.count} achievements for quarter #{quarter}: #{achievements.pluck(:month, :status)}"
      Rails.logger.info "All achievements for this user_detail: #{user_detail.achievements.pluck(:month, :status)}"

      if achievements.any?
        Rails.logger.info "Sending quarterly L1 email to #{l1_email} for employee #{employee_detail.employee_name} - Quarter: #{quarter}"
        ApprovalMailer.quarterly_l1_approval_request(employee_detail, quarter, achievements, l1_email).deliver_now
        Rails.logger.info "Quarterly L1 email sent successfully to #{l1_email}"
        { success: true, message: "Email sent to L1 manager" }
      else
        Rails.logger.warn "No achievements found for quarter #{quarter} - email not sent"
        { success: false, message: "No achievements for this quarter" }
      end
    rescue => e
      Rails.logger.error "Failed to send quarterly L1 email: #{e.message}"
      Rails.logger.error "Backtrace: #{e.backtrace.first(5).join("\n")}"
      { success: false, message: "Email sending failed: #{e.message}" }
    end
  end

  def send_quarterly_submission_confirmation_email(employee_detail, quarter, user_detail)
    return { success: false, message: "Employee email not found" } unless employee_detail.employee_email.present?

    begin
      # Get achievements for the quarter
      quarter_months = get_quarter_months_from_quarter_name(quarter)
      Rails.logger.info "Sending submission confirmation email for quarter: #{quarter}, months: #{quarter_months}"

      # Reload user_detail to get fresh achievements from database
      user_detail.reload
      achievements = user_detail.achievements.where(month: quarter_months)

      Rails.logger.info "Found #{achievements.count} achievements for submission confirmation"

      if achievements.any?
        Rails.logger.info "Sending quarterly submission confirmation email to #{employee_detail.employee_email} for employee #{employee_detail.employee_name} - Quarter: #{quarter}"
        ApprovalMailer.quarterly_submission_confirmation(employee_detail, quarter, achievements).deliver_now
        Rails.logger.info "Quarterly submission confirmation email sent successfully to #{employee_detail.employee_email}"
        { success: true, message: "Submission confirmation email sent to employee" }
      else
        Rails.logger.warn "No achievements found for quarter #{quarter} - confirmation email not sent"
        { success: false, message: "No achievements for this quarter" }
      end
    rescue => e
      Rails.logger.error "Failed to send quarterly submission confirmation email: #{e.message}"
      Rails.logger.error "Backtrace: #{e.backtrace.first(5).join("\n")}"
      { success: false, message: "Email sending failed: #{e.message}" }
    end
  end

  def get_quarter_months_from_quarter_name(quarter)
    case quarter
    when "Q1", /Q1\s*\(/
      %w[april may june]
    when "Q2", /Q2\s*\(/
      %w[july august september]
    when "Q3", /Q3\s*\(/
      %w[october november december]
    when "Q4", /Q4\s*\(/
      %w[january february march]
    else
      []
    end
  end

  def process_quarterly_achievements(department_id, activity_id, employee_detail_id, details)
    # Find the user detail record
    user_detail = UserDetail.find_by(
      department_id: department_id,
      activity_id: activity_id,
      employee_detail_id: employee_detail_id
    )

    return unless user_detail

    # Define quarterly mappings
    quarters = {
      "q1_achievement" => [ "april", "may", "june" ],
      "q2_achievement" => [ "july", "august", "september" ],
      "q3_achievement" => [ "october", "november", "december" ],
      "q4_achievement" => [ "january", "february", "march" ]
    }

    quarters.each do |quarter_key, months|
      quarter_achievement = details[quarter_key] || details[quarter_key.to_sym]
      next if quarter_achievement.blank?

      # Calculate target for the quarter
      total_target = 0
      months.each do |month|
        target_value = user_detail.send(month.to_sym) if user_detail.respond_to?(month.to_sym)
        if target_value.present?
          begin
            total_target += target_value.to_f
          rescue
            # Skip invalid values
          end
        end
      end

      next if total_target == 0

      # Calculate achievement value from percentage
      begin
        percentage = quarter_achievement.to_f
        achievement_value = (total_target * percentage / 100).round(2)
      rescue
        next
      end

      # Distribute achievement across months in the quarter
      months.each do |month|
        target_value = user_detail.send(month.to_sym) if user_detail.respond_to?(month.to_sym)
        next unless target_value.present?

        begin
          target = target_value.to_f
          month_achievement = (target * percentage / 100).round(2)

          # Find or create achievement record
          achievement = Achievement.find_or_initialize_by(
            user_detail: user_detail,
            month: month
          )

          achievement.achievement = month_achievement
          achievement.save
        rescue
          # Skip invalid values
        end
      end
    end
  end
end
