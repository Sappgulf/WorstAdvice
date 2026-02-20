require 'xcodeproj'

project_path = ARGV[0]
project = Xcodeproj::Project.open(project_path)

# 1. Remove all old references to ensure a clean slate
project.files.select { |f| f.path =~ /ShakeDetector\.swift$/ }.each do |ref|
    ref.build_files.each { |b| b.remove_from_project }
    ref.remove_from_project
end

# 2. Get main target
target = project.targets.find { |t| t.name == 'Badvice' }

# 3. Find Badvice -> Shared group
main_group = project.main_group.groups.find { |g| g.name == 'Badvice' } || project.main_group
shared_group = main_group.groups.find { |g| g.name == 'Shared' } || main_group.new_group('Shared', 'Shared')

# 4. We will add the file reference with an absolute path to bypass relative group path confusion
file_path = File.expand_path("Badvice/Shared/ShakeDetector.swift")

# Actually, the best robust way in XcodepRoject is to use new_reference on the group
file_ref = shared_group.new_reference(file_path)

target.source_build_phase.add_file_reference(file_ref)

project.save
puts "Added ShakeDetector via new_reference with absolute path."
