import SwiftUI

struct CrownPickerBox: View {
    let label: String
    @Binding var value: Double
    let step: Double
    let isWeight: Bool
    
    @FocusState private var isFocused: Bool
    
    var body: some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.system(size: 14, weight: .regular, design: .default))
                .foregroundColor(.gray)
            
            HStack(spacing: 8) {
                Button(action: {
                    value = max(0, value - step)
                }) {
                    Image(systemName: "minus")
                        .font(.system(size: 12, weight: .bold))
                }
                .buttonStyle(PlainButtonStyle())
                .foregroundColor(.green)
                
                Text(isWeight ? String(format: "%.1f", value) : String(format: "%.0f", value))
                    .font(.system(size: 28, weight: .semibold, design: .rounded).monospacedDigit())
                    .minimumScaleFactor(0.4)
                    .lineLimit(1)
                    .frame(minWidth: 40)
                
                Button(action: {
                    value += step
                }) {
                    Image(systemName: "plus")
                        .font(.system(size: 12, weight: .bold))
                }
                .buttonStyle(PlainButtonStyle())
                .foregroundColor(.green)
            }
        }
        .padding()
        .background(Color(white: 0.11)) // approx #1c1c1e
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isFocused ? Color.green : Color.clear, lineWidth: 2)
        )
        .focusable()
        .focused($isFocused)
        .digitalCrownRotation(
            $value,
            from: 0,
            through: 999,
            by: step,
            sensitivity: .low,
            isContinuous: false,
            isHapticFeedbackEnabled: true
        )
        .onTapGesture {
            isFocused = true
        }
    }
}
