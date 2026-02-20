require 'xcodeproj'

project_path = '/Users/austinbeatty/Downloads/WorstAdvice/Badvice.xcodeproj'
project = Xcodeproj::Project.open(project_path)

target = project.targets.find { |t| t.name == 'Badvice' }

badvice_group = project.main_group.children.find { |c| c.name == 'Badvice' || c.path == 'Badvice' }
views_group = badvice_group.children.find { |c| c.name == 'Views' || c.path == 'Views' }
shared_group = badvice_group.children.find { |c| c.name == 'Shared' || c.path == 'Shared' }
engine_group = badvice_group.children.find { |c| c.name == 'Engine' || c.path == 'Engine' }

f1 = views_group.new_file('GenerateTabView.swift')
f2 = views_group.new_file('ToastView.swift')
f3 = shared_group.new_file('ShakeDetector.swift')
f4 = shared_group.new_file('DeviceCapabilityProfile.swift')
f5 = engine_group.new_file('AdviceEngine+Vocabulary.swift')

target.add_file_references([f1, f2, f3, f4, f5])
project.save
puts "Successfully added files to Xcode project."
