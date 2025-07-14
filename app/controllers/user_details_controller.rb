# app/controllers/user_details_controller.rb
class UserDetailsController < ApplicationController
  before_action :set_user_detail, only: [:show, :edit, :update, :destroy]
  
  def index
    @user_details = UserDetail.includes(:department, :activity).all
  end
  
  def show
  end
  
  def new
    @user_detail = UserDetail.new
    @departments = Department.all
    @activities = []
    @user_details = UserDetail.includes(:department, :activity).all
  end
  
  def create
    @user_detail = UserDetail.new(user_detail_params)
    
    if @user_detail.save
      redirect_to new_user_detail_path, notice: 'User detail was successfully created.'
    else
      @departments = Department.all
      @activities = @user_detail.department_id.present? ? 
                    Activity.where(department_id: @user_detail.department_id) : []
      @user_details = UserDetail.includes(:department, :activity).all
      render :new
    end
  end
  
  def edit
    @departments = Department.all
    @activities = Activity.where(department_id: @user_detail.department_id)
  end
  
  def update
    if @user_detail.update(user_detail_params)
      redirect_to @user_detail, notice: 'User detail was successfully updated.'
    else
      @departments = Department.all
      @activities = Activity.where(department_id: @user_detail.department_id)
      render :edit
    end
  end
  
  def destroy
    @user_detail.destroy
    redirect_to user_details_url, notice: 'User detail was successfully deleted.'
  end
  
  # AJAX method to get activities based on department
  def get_activities
    department_id = params[:department_id]
    
    if department_id.present?
      department = Department.find(department_id)
      activities = department.activities.select(:id, :activity_name, :unit, :weight)
      
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
  
  # Create individual records one by one
  def bulk_create
    department_id = params[:department_id]
    user_details_params = params[:user_details]
    
    if department_id.blank?
      render json: { error: 'Department ID is required' }, status: :bad_request
      return
    end
    
    if user_details_params.blank?
      render json: { error: 'No user details provided' }, status: :bad_request
      return
    end
    
    created_count = 0
    updated_count = 0
    errors = []
    
    user_details_params.each do |activity_id, details|
      begin
        # Check if record already exists
        existing_record = UserDetail.find_by(
          department_id: department_id,
          activity_id: activity_id
        )
        
        if existing_record
          # Update existing record one by one
          if existing_record.update(
            april: details[:april],
            may: details[:may],
            june: details[:june],
            july: details[:july],
            august: details[:august],
            september: details[:september],
            october: details[:october],
            november: details[:november],
            december: details[:december],
            january: details[:january],
            february: details[:february],
            march: details[:march]
          )
            updated_count += 1
          else
            errors << "Failed to update activity #{activity_id}: #{existing_record.errors.full_messages.join(', ')}"
          end
        else
          # Create new record one by one
          new_record = UserDetail.new(
            department_id: department_id,
            activity_id: activity_id,
            april: details[:april],
            may: details[:may],
            june: details[:june],
            july: details[:july],
            august: details[:august],
            september: details[:september],
            october: details[:october],
            november: details[:november],
            december: details[:december],
            january: details[:january],
            february: details[:february],
            march: details[:march]
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
    
    if errors.empty?
      message = []
      message << "#{created_count} records created" if created_count > 0
      message << "#{updated_count} records updated" if updated_count > 0
      
      render json: { 
        success: true, 
        message: message.join(', '),
        created: created_count,
        updated: updated_count
      }
    else
      render json: { 
        success: false, 
        error: "Some records failed to save",
        errors: errors,
        created: created_count,
        updated: updated_count
      }, status: :unprocessable_entity
    end
  end
  
  private
  
  def set_user_detail
    @user_detail = UserDetail.find(params[:id])
  end
  
  def user_detail_params
    params.require(:user_detail).permit(:department_id, :activity_id, :april, :may, :june, 
                                        :july, :august, :september, :october, :november, 
                                        :december, :january, :february, :march)
  end
  
  # Strong parameters for bulk create
  def bulk_create_params
    params.permit(:department_id, user_details: {})
  end
end