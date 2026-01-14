#!/usr/bin/env ruby
# Script to cleanup duplicate UserDetail records
# Run this with: rails runner cleanup_duplicates.rb

puts "=== Cleaning up Duplicate UserDetail Records ==="

# Find all user details with their combinations
all_user_details = UserDetail.includes(:employee_detail, :department, :activity)
                            .where.not(employee_detail_id: nil)
                            .where.not(department_id: nil)
                            .where.not(activity_id: nil)

puts "Total UserDetail records: #{all_user_details.count}"

# Group by employee + department + activity combination
combinations = {}
all_user_details.each do |ud|
  key = "#{ud.employee_detail_id}_#{ud.department_id}_#{ud.activity_id}"
  combinations[key] ||= []
  combinations[key] << ud
end

# Find duplicates
duplicates = combinations.select { |key, records| records.count > 1 }
puts "Found #{duplicates.count} sets of duplicate records"

deleted_count = 0
duplicates.each do |key, records|
  # Keep the first record, delete the rest
  records_to_keep = records.first
  records_to_delete = records[1..-1]

  employee = records_to_keep.employee_detail
  department = records_to_keep.department
  activity = records_to_keep.activity

  puts "Employee: #{employee&.employee_name} | Department: #{department&.department_type} | Activity: #{activity&.activity_name}"
  puts "  Keeping ID: #{records_to_keep.id}, Deleting IDs: #{records_to_delete.map(&:id).join(', ')}"

  # Delete the duplicate records
  records_to_delete.each(&:destroy)
  deleted_count += records_to_delete.count

  puts "  ✅ Deleted #{records_to_delete.count} duplicate records"
end

puts "\n=== Cleanup Summary ==="
puts "Total duplicate records deleted: #{deleted_count}"
puts "Total UserDetail records after cleanup: #{UserDetail.count}"

# Show employee-department combinations
puts "\n=== Employee-Department Combinations ==="
combinations = UserDetail.joins(:employee_detail, :department)
                         .group('employee_details.employee_name, employee_details.employee_code, departments.department_type')
                         .count

combinations.each do |(employee_name, employee_code, department_type), activity_count|
  puts "#{employee_name} (#{employee_code}) → #{department_type} (#{activity_count} activities)"
end

puts "\n✅ Cleanup completed!"
