require 'xcodeproj'
project = Xcodeproj::Project.open('Badvice.xcodeproj')
target = project.targets.find { |t| t.name == 'Badvice' }

views_group = project.main_group.find_subpath('Badvice/Views', true)
shared_group = project.main_group.find_subpath('Badvice/Shared', true)
engine_group = project.main_group.find_subpath('Badvice/Engine', true)

f1 = views_group.new_file('GenerateTabView.swift')
f2 = views_group.new_file('ToastView.swift')
f3 = shared_group.new_file('ShakeDetector.swift')
f4 = shared_group.new_file('DeviceCapabilityProfile.swift')
f5 = engine_group.new_file('AdviceEngine+Vocabulary.swift')

target.add_file_references([f1, f2, f3, f4, f5])
project.save
