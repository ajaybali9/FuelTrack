import SwiftUI

enum FTKeyboard {
    case `default`
    case decimalPad
    case numberPad
    case emailAddress
    case URL
}

struct FTKeyboardModifier: ViewModifier {
    let keyboard: FTKeyboard

    func body(content: Content) -> some View {
        #if os(iOS)
        content.keyboardType(uiKeyboardType)
        #else
        content
        #endif
    }

    #if os(iOS)
    private var uiKeyboardType: UIKeyboardType {
        switch keyboard {
        case .default: .default
        case .decimalPad: .decimalPad
        case .numberPad: .numberPad
        case .emailAddress: .emailAddress
        case .URL: .URL
        }
    }
    #endif
}
