require 'xcodeproj'

project_path = ARGV[0]
file_to_add = ARGV[1]
project = Xcodeproj::Project.open(project_path)

# Remove old references first
project.files.select { |f| f.path =~ /#{File.basename(file_to_add)}$/ }.each do |ref|
    ref.build_files.each { |b| b.remove_from_project }
    ref.remove_from_project
end

target = project.targets.find { |t| t.name == 'Badvice' }

# Add the file reference directly from the project root.
file_ref = project.main_group.new_reference(file_to_add)

target.source_build_phase.add_file_reference(file_ref)

project.save
puts "Successfully added #{file_to_add} to the root project."
