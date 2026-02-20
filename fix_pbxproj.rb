require 'xcodeproj'
project = Xcodeproj::Project.open('Badvice.xcodeproj')
target = project.targets.find { |t| t.name == 'Badvice' }

badvice_group = project.main_group.children.find { |c| c.path == 'Badvice' || c.name == 'Badvice' }
shared_group = badvice_group.children.find { |c| c.path == 'Shared' || c.name == 'Shared' }

to_remove = []
project.files.each do |f|
  if ['ShakeDetector.swift', 'DeviceCapabilityProfile.swift'].include?(f.name || f.path)
    to_remove << f
  end
end

to_remove.each do |f|
  target.source_build_phase.files_references.delete(f)
  f.remove_from_project
end

f1 = shared_group.new_file('ShakeDetector.swift')
f2 = shared_group.new_file('DeviceCapabilityProfile.swift')
target.add_file_references([f1, f2])

project.save
puts "Successfully fixed pbxproj for ShakeDetector and DeviceCapabilityProfile!"
