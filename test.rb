require 'xcodeproj'
project = Xcodeproj::Project.open('Badvice.xcodeproj')
project.main_group.children.each do |c|
  puts "#{c.name || c.path}"
end
