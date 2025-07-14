class DepartmentsController < ApplicationController
  before_action :set_department, only: [:show, :edit, :update, :destroy, :edit_data]

 def index
    @departments = Department.includes(:activities).all
    @department = Department.new
    3.times { @department.activities.build }

    respond_to do |format|
      format.html
      format.json do
        render json: @departments.as_json(include: {
          activities: {
            only: [:id, :activity_id, :activity_name, :unit, :weight]
          }
        }, only: [:id, :department_type, :theme_id, :theme_name])
      end
    end
  end


  def show
  end

  def new
    @department = Department.new
    3.times { @department.activities.build }
  end

  def create
    @department = Department.new(department_params)

    Rails.logger.info "Department params: #{department_params.inspect}"

    if @department.save
      Rails.logger.info "Department saved successfully with ID: #{@department.id}"
      redirect_to departments_path, notice: 'Department was successfully created.'
    else
      Rails.logger.error "Department save failed: #{@department.errors.full_messages}"
      @departments = Department.includes(:activities).all
      flash.now[:alert] = "Failed to create department: #{@department.errors.full_messages.join(', ')}"
      render :index, status: :unprocessable_entity
    end
  end

  def edit
    @departments = Department.includes(:activities).all
    render :index
  end

  def edit_data
    render json: {
      id: @department.id,
      department_type: @department.department_type,
      theme_id: @department.theme_id,
      theme_name: @department.theme_name,
      activities: @department.activities.map do |activity|
        {
          id: activity.id,
          activity_id: activity.activity_id,
          activity_name: activity.activity_name,
          unit: activity.unit,
          weight: activity.weight
        }
      end
    }
  end

  def update
    if @department.update(department_params)
      redirect_to departments_path, notice: 'Department was successfully updated.'
    else
      @departments = Department.includes(:activities).all
      flash.now[:alert] = "Failed to update department: #{@department.errors.full_messages.join(', ')}"
      render :index, status: :unprocessable_entity
    end
  end

  def destroy
    @department.destroy
    redirect_to departments_path, notice: 'Department was successfully deleted.'
  end

  private

  def set_department
    @department = Department.find(params[:id])
  end

  def department_params
    params.require(:department).permit(:department_type, :theme_id, :theme_name, 
    activities_attributes: [:id, :activity_id, :activity_name, :unit, :weight, :_destroy])
  end
end