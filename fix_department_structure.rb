#!/usr/bin/env ruby
# Script to fix the department structure - consolidate departments by type
# Run this with: rails runner fix_department_structure.rb

puts "=== Fixing Department Structure ==="

# Get all department types
department_types = Department.distinct.pluck(:department_type).compact

puts "Found department types: #{department_types.inspect}"

department_types.each do |dept_type|
  puts "\n--- Processing #{dept_type} ---"

  # Find all departments with this type
  departments = Department.where(department_type: dept_type)
  puts "Found #{departments.count} department records with type '#{dept_type}'"

  if departments.count > 1
    # Keep the first department as the master
    master_dept = departments.first
    duplicate_depts = departments.where.not(id: master_dept.id)

    puts "Master department: ID #{master_dept.id}"
    puts "Duplicate departments: #{duplicate_depts.pluck(:id).inspect}"

    # Move all UserDetail records to the master department
    duplicate_depts.each do |dup_dept|
      puts "  Moving #{dup_dept.user_details.count} user_details from dept #{dup_dept.id} to #{master_dept.id}"

      dup_dept.user_details.each do |ud|
        # Check if a UserDetail already exists for this employee+activity in master dept
        existing = UserDetail.find_by(
          employee_detail_id: ud.employee_detail_id,
          activity_id: ud.activity_id,
          department_id: master_dept.id
        )

        if existing
          puts "    Duplicate found - deleting UserDetail #{ud.id}"
          ud.destroy
        else
          puts "    Moving UserDetail #{ud.id} to master department"
          ud.update!(department_id: master_dept.id)
        end
      end

      # Move all Activities to the master department
      puts "  Moving #{dup_dept.activities.count} activities from dept #{dup_dept.id} to #{master_dept.id}"
      dup_dept.activities.update_all(department_id: master_dept.id)

      # Delete the duplicate department
      puts "  Deleting duplicate department #{dup_dept.id}"
      dup_dept.destroy
    end

    puts "  ✅ Consolidated #{dept_type} department"
  else
    puts "  No duplicates found for #{dept_type}"
  end
end

puts "\n=== Final Department Structure ==="
Department.all.each do |dept|
  employee_count = dept.user_details.joins(:employee_detail).distinct.count('employee_details.id')
  activity_count = dept.activities.count
  puts "#{dept.department_type} (ID: #{dept.id}) - #{employee_count} employees, #{activity_count} activities"
end

puts "\n✅ Department structure fixed!"
