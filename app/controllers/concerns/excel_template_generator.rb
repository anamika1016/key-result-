module ExcelTemplateGenerator
  extend ActiveSupport::Concern

  def generate_employee_template
    package = Axlsx::Package.new
    workbook = package.workbook

    workbook.add_worksheet(name: "Employee Template") do |sheet|
      # Add header row
      sheet.add_row [
        "Name",
        "Email",
        "Employee Code",
        "L1 Code",
        "L2 Code",
        "L3 Code",
        "L1 Name",
        "L2 Name",
        "L3 Name",
        "Post",
        "Department"
      ]

      # Add sample data row
      sheet.add_row [
        "John Doe",
        "john.doe@example.com",
        "EMP001",
        "L1001",
        "L2001",
        "L3001",
        "Manager Name",
        "Senior Manager Name",
        "Director Name",
        "Software Engineer",
        "IT"
      ]

      # Add another sample row
      sheet.add_row [
        "Jane Smith",
        "jane.smith@example.com",
        "EMP002",
        "L1001",
        "L2001",
        "L3001",
        "Manager Name",
        "Senior Manager Name",
        "Director Name",
        "Business Analyst",
        "Business"
      ]
    end

    package
  end
end
