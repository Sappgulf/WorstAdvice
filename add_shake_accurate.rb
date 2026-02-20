require 'xcodeproj'

project_path = ARGV[0]
project = Xcodeproj::Project.open(project_path)

# First, remove any existing ShakeDetector references
project.files.select { |f| f.path =~ /ShakeDetector\.swift$/ }.each do |ref|
    ref.build_files.each { |b| b.remove_from_project }
    ref.remove_from_project
end

# Find the main target
target = project.targets.find { |t| t.name == 'Badvice' }

# Add the file reference directly from the project root.
file_path = 'Badvice/Shared/ShakeDetector.swift'
file_ref = project.main_group.new_reference(file_path)

target.source_build_phase.add_file_reference(file_ref)

project.save
puts "Successfully added ShakeDetector.swift to the root project."
