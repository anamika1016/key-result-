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
    @departments = Department.select(:id, :department_type, :theme_name)
    @employee_details = EmployeeDetail.select(:id, :employee_name, :l1_employer_name, :l2_employer_name, :department)
    @users = User.select(:id, :email, :role) if params[:show_users]
    
    # Only load existing data when specific filters are applied
    @user_details = if params[:department_id].present? || params[:employee_detail_id].present?
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
    @activities = Activity.select(:id, :activity_name, :unit)
                         .where(department_id: @user_detail.department_id)
  end
  
  def update
    if @user_detail.update(user_detail_params)
      redirect_to new_user_detail_path, notice: 'User detail was successfully updated.'
    else
      @departments = Department.select(:id, :department_type)
      @activities = Activity.select(:id, :activity_name, :unit)
                           .where(department_id: @user_detail.department_id)
      render :edit
    end
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
      activities = Activity.select(:id, :activity_name, :unit, :weight)
                          .where(department_id: department_id)
      
      activities_data = activities.map do |activity|
        {
          id: activity.id,
          activity_name: activity.activity_name,
          unit: activity.unit,
          weight: activity.weight
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
      redirect_to user_details_path, alert: "Please upload a valid .xlsx or .xls file."
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
            l1_code = row["l1_code"]
            l1_employer_name = row["l1_employer_name"]
            l2_code = row["l2_code"]
            l2_employer_name = row["l2_employer_name"]
            department_type = row["department"]
            activity_name = row["activity_name"]
            theme_name = row["theme"]
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

            department = Department.find_or_create_by!(department_type: department_type) do |d|
              d.theme_name = theme_name
            end

            if department.theme_name.blank? && theme_name.present?
              department.update(theme_name: theme_name)
            end

            employee = EmployeeDetail.find_or_create_by!(
              employee_name: employee_name.strip,
              department: department_type.strip
            ) do |e|
              e.employee_id = SecureRandom.uuid
              e.employee_email = employee_email.to_s.strip
              e.employee_code = employee_code.to_s.strip
              e.l1_code = l1_code.to_s.strip
              e.l2_code = l2_code.to_s.strip
              e.l1_employer_name = l1_employer_name.to_s.strip
              e.l2_employer_name = l2_employer_name.to_s.strip
              e.post = "Imported"
            end

            activity = Activity.find_or_create_by!(
              activity_name: activity_name.strip,
              department_id: department.id
            ) do |a|
              a.unit = unit
              a.weight = 1.0
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
          redirect_to user_details_path, alert: "Partially imported: #{success_count} records saved, but #{errors.count} errors:\n#{errors.first(10).join("\n")}"
        else
          redirect_to user_details_path, alert: "Import failed. Errors:\n#{errors.first(10).join("\n")}"
        end
      else
        redirect_to user_details_path, notice: "Excel file imported successfully! #{success_count} records processed."
      end

    rescue => e
      Rails.logger.error "Import error: #{e.message}\n#{e.backtrace.join("\n")}"
      redirect_to user_details_path, alert: "Error reading Excel file: #{e.message}"
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

    if value.is_a?(String)
      return value.gsub('%', '').to_f
    elsif value.is_a?(Numeric) && value <= 1
      return (value * 100).round(2)
    else
      return value
    end
  end

  def load_form_data
    @departments = Department.select(:id, :department_type, :theme_name)
    @activities = @user_detail.department_id.present? ? 
                  Activity.select(:id, :activity_name, :unit)
                         .where(department_id: @user_detail.department_id) : []
    @user_details = UserDetail.includes(:department, :activity).limit(100)
  end

  def filter_conditions
    conditions = {}
    conditions[:department_id] = params[:department_id] if params[:department_id].present?
    conditions[:employee_detail_id] = params[:employee_detail_id] if params[:employee_detail_id].present?
    conditions
  end
end