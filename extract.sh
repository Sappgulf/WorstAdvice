#!/bin/bash
set -e

DIR="/Users/austinbeatty/Downloads/WorstAdvice/Badvice"

# 1. GenerateTabView.swift
echo "Extracting GenerateTabView..."
echo "import SwiftUI" > "$DIR/Views/GenerateTabView.swift"
echo "" >> "$DIR/Views/GenerateTabView.swift"
sed -n '319,$p' "$DIR/Views/AdviceCardView.swift" >> "$DIR/Views/GenerateTabView.swift"
sed -i '' '319,$d' "$DIR/Views/AdviceCardView.swift"

# 2. ShakeDetector.swift and DeviceCapabilityProfile.swift
echo "Extracting ShakeDetector and DeviceCapabilityProfile..."
echo "import CoreMotion" > "$DIR/Shared/ShakeDetector.swift"
echo "import Foundation" >> "$DIR/Shared/ShakeDetector.swift"
echo "import SwiftUI" >> "$DIR/Shared/ShakeDetector.swift"
echo "" >> "$DIR/Shared/ShakeDetector.swift"
sed -n '70,109p' "$DIR/Views/ContentView.swift" >> "$DIR/Shared/ShakeDetector.swift"

echo "import Foundation" > "$DIR/Shared/DeviceCapabilityProfile.swift"
echo "import UIKit" >> "$DIR/Shared/DeviceCapabilityProfile.swift"
echo "" >> "$DIR/Shared/DeviceCapabilityProfile.swift"
sed -n '110,167p' "$DIR/Views/ContentView.swift" | sed 's/private enum/enum/g' | sed 's/private struct/struct/g' >> "$DIR/Shared/DeviceCapabilityProfile.swift"

# Remove from ContentView.swift in reverse order
sed -i '' '110,167d' "$DIR/Views/ContentView.swift"
sed -i '' '68,109d' "$DIR/Views/ContentView.swift"

# 3. ToastView.swift
echo "Extracting ToastView..."
echo "import SwiftUI" > "$DIR/Views/ToastView.swift"
echo "" >> "$DIR/Views/ToastView.swift"
sed -n '9,116p' "$DIR/Views/Theme.swift" >> "$DIR/Views/ToastView.swift"
sed -i '' '9,116d' "$DIR/Views/Theme.swift"

# 4. AdviceEngine+Vocabulary.swift
echo "Extracting AdviceVocabulary..."
echo "import Foundation" > "$DIR/Engine/AdviceEngine+Vocabulary.swift"
echo "" >> "$DIR/Engine/AdviceEngine+Vocabulary.swift"
echo "extension AdviceEngine {" >> "$DIR/Engine/AdviceEngine+Vocabulary.swift"
sed -n '427,721p' "$DIR/Engine/AdviceEngine.swift" | sed 's/private static/static/g' >> "$DIR/Engine/AdviceEngine+Vocabulary.swift"
echo "}" >> "$DIR/Engine/AdviceEngine+Vocabulary.swift"
sed -i '' '427,721d' "$DIR/Engine/AdviceEngine.swift"

echo "Done!"
