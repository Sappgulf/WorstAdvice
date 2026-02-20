require 'xcodeproj'

project_path = ARGV[0]
project = Xcodeproj::Project.open(project_path)

# Find all file references named "ShakeDetector.swift"
shake_refs = project.files.select { |f| f.path =~ /ShakeDetector\.swift$/ }
puts "Found #{shake_refs.count} references to ShakeDetector.swift"

# Keep only the one pointing to the correct original file if possible, or just the first one.
# It seems "Shared/ShakeDetector.swift" might be the true path based on previous grep results, Let's check which is correct.
# Actually, the file is in Badvice/Utils/ShakeDetector.swift, so none of these reference paths might be completely right if they are missing the group path, but let's just clear ALL of them and re-add.

shake_refs.each do |ref|
    ref.build_files.each do |build_file|
        build_file.remove_from_project
    end
    ref.remove_from_project
end

project.save
puts "Removed all ShakeDetector references."
