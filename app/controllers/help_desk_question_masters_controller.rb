class HelpDeskQuestionMastersController < ApplicationController
  before_action :ensure_hod!
  before_action :set_help_desk_question_master, only: [ :edit, :update, :destroy ]
  before_action :load_help_desk_question_support_data, only: [ :index, :create, :edit, :update ]

  def index
    @help_desk_question_master = HelpDeskQuestionMaster.new(active: true)
  end

  def create
    @help_desk_question_master = HelpDeskQuestionMaster.new(help_desk_question_master_params)

    if @help_desk_question_master.save
      redirect_to help_desk_question_masters_path, notice: "Help desk question created successfully."
    else
      render :index, status: :unprocessable_entity
    end
  end

  def edit
    render :index
  end

  def update
    if @help_desk_question_master.update(help_desk_question_master_params)
      redirect_to help_desk_question_masters_path, notice: "Help desk question updated successfully."
    else
      render :index, status: :unprocessable_entity
    end
  end

  def destroy
    @help_desk_question_master.destroy
    redirect_to help_desk_question_masters_path, notice: "Help desk question deleted successfully."
  end

  private

  def set_help_desk_question_master
    @help_desk_question_master = HelpDeskQuestionMaster.find(params[:id])
  end

  def load_help_desk_question_support_data
    @departments = Department.selectable_verticals
    @help_desk_question_masters = HelpDeskQuestionMaster.includes(:department).ordered_for_display
  end

  def help_desk_question_master_params
    params.require(:help_desk_question_master).permit(:department_id, :request_type, :question_text, :active)
  end

  def ensure_hod!
    return if current_user&.hod?

    redirect_to root_path, alert: "You are not authorized to access this page."
  end
end
