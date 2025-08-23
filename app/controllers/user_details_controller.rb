class UserDetailsController < ApplicationController
  before_action :set_user_detail, only: [:show, :edit, :update, :destroy]
  
  def index
    if current_user.role == "employee" || current_user.role == "l1_employer" || current_user.role == "l2_employer"
      employee_detail = EmployeeDetail.find_by(employee_email: current_user.email)

      @user_details = if employee_detail
        UserDetail.includes(:department, :activity, :employee_detail)
                  .where(employee_detail_id: employee_detail.id)
                  .page(params[:page]).per(50)
      else
        UserDetail.none.page(params[:page]).per(50)
      end

    elsif current_user.role == "hod"
      @user_details = UserDetail.includes(:department, :activity, :employee_detail)
                                .page(params[:page]).per(50)
    end
  end

    def new
    @user_detail = UserDetail.new

    # Load unique departments
    @departments = Department.select('DISTINCT ON (department_type) id, department_type')

    # Filter employees based on selected department
    if params[:department_id].present?
      dept_type = Department.find(params[:department_id]).department_type
      @employee_details = EmployeeDetail.where(department: dept_type)
                                        .select(:id, :employee_name, :l1_employer_name, :l2_employer_name, :department)
                                        .order(:employee_name)
    else
      @employee_details = EmployeeDetail.none
    end

    # Find selected employee to show L1/L2
    if params[:employee_detail_id].present?
      @selected_employee = EmployeeDetail.find_by(id: params[:employee_detail_id])
    end

    @users = User.select(:id, :email, :role) if params[:show_users]

    # FIXED: Only load user_details when BOTH department and employee are selected
    # This prevents showing all data when only one filter is applied
    @user_details = if params[:department_id].present? && params[:employee_detail_id].present?
      UserDetail.includes(:department, :activity, :employee_detail)
                .where(filter_conditions)
                .limit(100)
    else
      UserDetail.none
    end
  end

  def create
    @user_detail = UserDetail.new(user_detail_params)
    
    if @user_detail.save
      redirect_to new_user_detail_path, notice: 'User detail was successfully created.'
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
    if @user_detail.update(user_detail_params)
      redirect_to new_user_detail_path, notice: 'User detail was successfully updated.'
    else
      @departments = Department.select(:id, :department_type)
      @activities = Activity.select(:id, :activity_name, :unit, :theme_name)
                           .where(department_id: @user_detail.department_id)
      render :edit
    end
  end


def update_quarterly_achievements
  # Get the correct parameters
  selected_quarter = params[:selected_quarter]
  achievement_data = params[:achievements] || {}
  success_count = 0
  errors = []
  updated_activities = []

  Rails.logger.debug "QUARTERLY UPDATE DEBUG:"
  Rails.logger.debug "Selected Quarter: #{selected_quarter}"
  Rails.logger.debug "Achievement Data: #{achievement_data.inspect}"

  if achievement_data.empty?
    flash[:alert] = "No achievement data received. Please try again."
    redirect_to quarterly_edit_all_user_details_path
    return
  end

  # Define quarter months to limit updates to selected quarter only
  quarter_months = case selected_quarter
  when 'Q1'
    ['april', 'may', 'june']
  when 'Q2'
    ['july', 'august', 'september']
  when 'Q3'
    ['october', 'november', 'december']
  when 'Q4'
    ['january', 'february', 'march']
  else
    []
  end

  Rails.logger.debug "Quarter Months: #{quarter_months}"

  # Track which employee_details had changes to reset their entire quarter
  employee_details_with_changes = Set.new

  ActiveRecord::Base.transaction do
    achievement_data.each do |user_detail_id, monthly_data|
      user_detail = UserDetail.find_by(id: user_detail_id)
      next unless user_detail

      Rails.logger.debug "Processing UserDetail #{user_detail_id}: #{user_detail.activity.activity_name}"

      activity_updated = false
      
      monthly_data.each do |month, values|
        # IMPORTANT: Only process months that belong to the selected quarter
        next unless quarter_months.include?(month)
        
        achievement_value = values[:achievement]
        employee_remarks = values[:employee_remarks]

        Rails.logger.debug "Month: #{month}, Achievement: #{achievement_value}, Remarks: #{employee_remarks}"

        # Skip if both achievement and remarks are blank
        next if achievement_value.blank? && employee_remarks.blank?

        # Find or initialize achievement
        achievement = Achievement.find_or_initialize_by(
          user_detail: user_detail, 
          month: month
        )
        
        # Store old values for comparison
        old_achievement = achievement.achievement
        old_remarks = achievement.employee_remarks
        
        # Update values
        achievement.achievement = achievement_value.present? ? achievement_value : nil
        achievement.employee_remarks = employee_remarks.present? ? employee_remarks : nil
        
        Rails.logger.debug "Old Achievement: #{old_achievement}, New: #{achievement.achievement}"
        
        # Save if there are changes
        if achievement.achievement != old_achievement || achievement.employee_remarks != old_remarks
          if achievement.save
            success_count += 1
            activity_updated = true
            # Mark this employee_detail as having changes for quarterly status update
            employee_details_with_changes.add(user_detail.employee_detail_id)
            Rails.logger.debug "Successfully saved achievement for #{month}"
          else
            error_msg = "Failed to save #{month.capitalize} for #{user_detail.activity.activity_name}: #{achievement.errors.full_messages.join(', ')}"
            errors << error_msg
            Rails.logger.error error_msg
          end
        else
          Rails.logger.debug "No changes detected for #{month}"
        end
      end
      
      if activity_updated
        activity_name = "#{user_detail.employee_detail&.employee_name} - #{user_detail.activity.activity_name}"
        updated_activities << activity_name
        Rails.logger.debug "Activity updated: #{activity_name}"
      end
    end

    # FIXED: After all individual updates, set entire quarter to pending for employees who had changes
    employee_details_with_changes.each do |employee_detail_id|
      Rails.logger.debug "Setting entire quarter to pending for employee_detail_id: #{employee_detail_id}"
      
      # Find all user_details for this employee in current quarter
      employee_user_details = UserDetail.where(employee_detail_id: employee_detail_id)
      
      employee_user_details.each do |user_detail|
        # Set all achievements for this quarter to pending
        user_detail.achievements.where(month: quarter_months).where.not(achievement: [nil, '']).each do |quarter_achievement|
          old_status = quarter_achievement.status
          quarter_achievement.update(status: 'pending')
          Rails.logger.debug "Updated #{user_detail.activity.activity_name} #{quarter_achievement.month} from #{old_status} to pending"
          
          # Reset approval remarks for quarterly approval
          if quarter_achievement.achievement_remark
            quarter_achievement.achievement_remark.update(
              l1_remarks: nil,
              l1_percentage: nil,
              l2_remarks: nil,
              l2_percentage: nil
            )
            Rails.logger.debug "Reset approval remarks for quarterly re-approval"
          end
        end
      end
    end
  end

  # FIXED: Handle response messages
  if errors.empty?
    if success_count > 0
      flash[:notice] = "✅ Successfully updated #{success_count} achievement records across #{updated_activities.count} activities!"
      if updated_activities.any?
        if updated_activities.count <= 3
          flash[:notice] += " Updated activities: #{updated_activities.join(', ')}"
        else
          flash[:notice] += " Updated activities: #{updated_activities.first(3).join(', ')} and #{updated_activities.count - 3} more..."
        end
      end
      flash[:notice] += " All updated achievements are now in 'pending' status and need L1/L2 approval."
    else
      flash[:notice] = "No changes were made to the achievements."
    end
  else
    flash[:alert] = "⚠️ Some updates failed: #{errors.first(2).join('; ')}"
    flash[:alert] += " and #{errors.count - 2} more errors..." if errors.count > 2
  end
  
  redirect_to quarterly_edit_all_user_details_path
  
rescue => e
  Rails.logger.error "Quarterly update error: #{e.message}\n#{e.backtrace.join("\n")}"
  flash[:alert] = "❌ An error occurred while updating achievements: #{e.message}"
  redirect_to quarterly_edit_all_user_details_path
end

# FIXED: Quarterly edit all method
def quarterly_edit_all
  Rails.logger.debug "QUARTERLY EDIT ALL - User Role: #{current_user.role}"
  
  if current_user.role == "employee" || current_user.role == "l1_employer" || current_user.role == "l2_employer"
    employee_detail = EmployeeDetail.find_by(employee_email: current_user.email)
    @user_details = if employee_detail
      UserDetail.includes(:department, :activity, :employee_detail, achievements: :achievement_remark)
                .where(employee_detail_id: employee_detail.id)
                .order('departments.department_type, activities.activity_name')
    else
      UserDetail.none
    end
  elsif current_user.role == "hod"
    @user_details = UserDetail.includes(:department, :activity, :employee_detail, achievements: :achievement_remark)
                              .order('departments.department_type, employee_details.employee_name, activities.activity_name')
  else
    @user_details = UserDetail.none
  end

  Rails.logger.debug "Found #{@user_details.count} user details for quarterly editing"

  # FIXED: Correct quarter definitions to match the system
  @quarters = [
    { name: "Q1", months: ["april", "may", "june"], label: "Q1 (Apr-Jun)" },
    { name: "Q2", months: ["july", "august", "september"], label: "Q2 (Jul-Sep)" },
    { name: "Q3", months: ["october", "november", "december"], label: "Q3 (Oct-Dec)" },
    { name: "Q4", months: ["january", "february", "march"], label: "Q4 (Jan-Mar)" }
  ]
end
  
  def destroy
    @user_detail = UserDetail.find(params[:id])
    @user_detail.destroy
    redirect_to new_user_detail_path, notice: "User detail was successfully deleted."
  end

  def get_user_detail
    if ["employee", "l1_employer", "l2_employer"].include?(current_user.role)
      @employee_detail = EmployeeDetail.find_by(employee_email: current_user.email)

      @user_details = if @employee_detail
        UserDetail.includes(:department, :activity, :employee_detail)
                  .where(employee_detail_id: @employee_detail.id)
                  .limit(100)
      else
        UserDetail.none
      end

    elsif current_user.role == "hod"
      @user_details = UserDetail.includes(:department, :activity, :employee_detail)
                                .limit(100)
      @employee_detail = nil
    end
  end
  
  def submit_achievements
    achievement_data = params[:achievement] || {}
    success_count = 0

    ActiveRecord::Base.transaction do
      achievement_data.each do |user_detail_id, monthly_data|
        user_detail = UserDetail.find_by(id: user_detail_id)
        next unless user_detail

        monthly_data.each do |month, values|
          achievement_value = values[:achievement]
          employee_remarks = values[:employee_remarks]

          next if achievement_value.blank?
          target_value = user_detail.send(month)
          next if target_value.blank?

          achievement = Achievement.find_or_initialize_by(
            user_detail: user_detail, 
            month: month
          )
          
          achievement.achievement = achievement_value
          achievement.employee_remarks = employee_remarks
          
          if achievement.save
            success_count += 1
          end
        end
      end
    end

    render json: { success: true, count: success_count }
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
      render json: { error: 'Department ID is required' }, status: :bad_request
    end
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Department not found' }, status: :not_found
  rescue => e
    render json: { error: 'An error occurred while fetching activities' }, status: :internal_server_error
  end
  
  def bulk_create
    Rails.logger.info "=== BULK CREATE DEBUG ==="
    
    department_id = params[:department_id]
    employee_detail_id = params[:employee_detail_id]
    user_details_params = params[:user_details]

    # Enhanced validation
    if department_id.blank?
      render json: { error: 'Department ID is required' }, status: :bad_request
      return
    end

    if employee_detail_id.blank?
      render json: { error: 'Employee Detail ID is required' }, status: :bad_request
      return
    end

    if user_details_params.blank?
      render json: { error: 'No user details provided' }, status: :bad_request
      return
    end

    # Validate that department and employee exist
    unless Department.exists?(department_id)
      render json: { error: 'Department not found' }, status: :not_found
      return
    end

    unless EmployeeDetail.exists?(employee_detail_id)
      render json: { error: 'Employee not found' }, status: :not_found
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
    ).index_by(&:activity_id)

    ActiveRecord::Base.transaction do
      user_details_params.each do |activity_id, details|
        begin
          unless Activity.exists?(activity_id)
            errors << "Activity with ID #{activity_id} not found"
            next
          end

          month_data = {
            april: extract_month_value(details, 'april'),
            may: extract_month_value(details, 'may'),
            june: extract_month_value(details, 'june'),
            july: extract_month_value(details, 'july'),
            august: extract_month_value(details, 'august'),
            september: extract_month_value(details, 'september'),
            october: extract_month_value(details, 'october'),
            november: extract_month_value(details, 'november'),
            december: extract_month_value(details, 'december'),
            january: extract_month_value(details, 'january'),
            february: extract_month_value(details, 'february'),
            march: extract_month_value(details, 'march')
          }

          existing_record = existing_records[activity_id.to_i]

          if existing_record
            if existing_record.update(month_data)
              updated_count += 1
            else
              errors << "Failed to update activity #{activity_id}: #{existing_record.errors.full_messages.join(', ')}"
            end
          else
            new_record = UserDetail.new(
              department_id: department_id,
              activity_id: activity_id,
              employee_detail_id: employee_detail_id,
              **month_data
            )

            if new_record.save
              created_count += 1
            else
              errors << "Failed to create activity #{activity_id}: #{new_record.errors.full_messages.join(', ')}"
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
      message = ["No changes made"] if message.empty?

      response_data = {
        success: true,
        message: message.join(', '),
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
        response.headers['Content-Disposition'] = 'attachment; filename="user_details.xlsx"'
      }
    end
  end

  def import
    file = params[:file]

    unless file && [".xlsx", ".xls"].include?(File.extname(file.original_filename))
      redirect_to new_user_detail_path, alert: "Please upload a valid .xlsx or .xls file."
      return
    end

    begin
      spreadsheet = Roo::Excelx.new(file.tempfile.path)
      header = spreadsheet.row(1)
      


      errors = []
      success_count = 0
      batch_size = 100

      # Process in batches for better performance
      (2..spreadsheet.last_row).each_slice(batch_size) do |rows|
        ActiveRecord::Base.transaction do
          rows.each do |i|
            row_data = spreadsheet.row(i)
            row = {}
            header.each_with_index do |col_name, index|
              next if col_name.nil?
              key = col_name.to_s.strip.downcase.gsub(/\s+/, '_')
              row[key] = row_data[index]
            end



            employee_name = row["employee_name"]
            employee_email = row["employee_email"]
            employee_code = row["employee_code"]
            
            # FIXED: Better mobile number extraction with more column name variations
            mobile_number = row["mobile_no"] || row["mobile_number"] || row["mobile"] || 
                           row["mobile_no."] || row["mobile_number."] || row["mobile."] ||
                           row["mobile_no_"] || row["mobile_number_"] || row["mobile_"]
            
            l1_code = row["l1_code"]
            l1_employer_name = row["l1_employer_name"]
            l2_code = row["l2_code"]
            l2_employer_name = row["l2_employer_name"]
            department_type = row["department"]
            activity_name = row["activity_name"]
            activity_theme_name = row["theme"] || row["activity_theme"]
            unit = row["unit"] || "Count"



            months = {
              april: normalize_percentage(row["april"]),
              may: normalize_percentage(row["may"]),
              june: normalize_percentage(row["june"]),
              july: normalize_percentage(row["july"]),
              august: normalize_percentage(row["august"]),
              september: normalize_percentage(row["september"]),
              october: normalize_percentage(row["october"]),
              november: normalize_percentage(row["november"]),
              december: normalize_percentage(row["december"]),
              january: normalize_percentage(row["january"]),
              february: normalize_percentage(row["february"]),
              march: normalize_percentage(row["march"])
            }



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

            # FIXED: Better employee creation/update logic
            employee = EmployeeDetail.find_or_create_by!(
              employee_name: employee_name.strip,
              department: department_type.strip
            ) do |e|
              e.employee_id = SecureRandom.uuid
              e.employee_email = employee_email.to_s.strip
              e.employee_code = employee_code.to_s.strip
              e.mobile_number = mobile_number.to_s.strip if mobile_number.present?
              e.l1_code = l1_code.to_s.strip
              e.l2_code = l2_code.to_s.strip
              e.l1_employer_name = l1_employer_name.to_s.strip
              e.l2_employer_name = l2_employer_name.to_s.strip
              e.post = "Imported"
            end

            # FIXED: Always update mobile number if provided in Excel
            if mobile_number.present?
              if employee.mobile_number != mobile_number.to_s.strip
                employee.update!(mobile_number: mobile_number.to_s.strip)
              end
            end

            activity = Activity.find_or_create_by!(
              activity_name: activity_name.strip,
              department_id: department.id
            ) do |a|
              a.unit = unit
              a.weight = 1.0
              a.theme_name = activity_theme_name.to_s.strip if activity_theme_name.present?
            end

            # Update theme_name if provided and different
            if activity_theme_name.present? && activity.theme_name != activity_theme_name.strip
              activity.update(theme_name: activity_theme_name.strip)
            end

            begin
              UserDetail.create!(
                employee_detail_id: employee.id,
                department_id: department.id,
                activity_id: activity.id,
                **months
              )
              success_count += 1
            rescue ActiveRecord::RecordInvalid => e
              errors << "Row #{i}: #{e.message}"
            end
          end
        end
      end

      if errors.any?
        if success_count > 0
          redirect_to new_user_detail_path, alert: "Partially imported: #{success_count} records saved, but #{errors.count} errors:\n#{errors.first(10).join("\n")}"
        else
          redirect_to new_user_detail_path, alert: "Import failed. Errors:\n#{errors.first(10).join("\n")}"
        end
      else
        redirect_to new_user_detail_path, notice: "Excel file imported successfully! #{success_count} records processed."
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
                                        :december, :january, :february, :march, :employee_detail_id, :employee_detail_email)
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
      if cleaned_value.include?('%')
        return cleaned_value.gsub('%', '').to_f
      end
      
      # Handle numeric strings - return as is, don't convert to percentage
      if cleaned_value.match?(/^\d+\.?\d*$/)
        return cleaned_value.to_f
      end
      
      # Return the original string if it's not numeric
      return cleaned_value
    elsif value.is_a?(Numeric)
      # FIXED: Don't automatically convert numbers to percentages
      # Only convert if the value is explicitly a decimal percentage (0.0 to 1.0)
      # AND it's marked as a percentage in the original data
      return value
    else
      # For other types, try to convert to string and then process
      return normalize_percentage(value.to_s)
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
end