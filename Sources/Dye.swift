#if os(macOS)
import Darwin.C.stdio
#elseif os(Linux)
import Glibc
#elseif os(Windows)
import WinSDK
#endif

#if os(Windows)
typealias NativeFileHandle = HANDLE
#else
typealias NativeFileHandle = UnsafeMutablePointer<FILE>
#endif

public struct OutputStream: TextOutputStream {
    // MARK: - Public stored properties

    public var styling: Styling = .auto

    // MARK: - Private stored properties

    private var file: NativeFileHandle
    private var colorStorage = Colors(foreground: nil, background: nil)
    private var styleStorage = Style(rawValue: 0)
    private var requiresStyleFlushNextTime = false
#if os(Windows)
    private var originalConsoleAttributes: WORD
#endif

    // MARK: - Public static functions

    public static func standardError(
        foregroundColor: Color? = nil,
        backgroundColor: Color? = nil,
        style: Style = Style(rawValue: 0)
    ) -> OutputStream
    {
        let colors = Colors(foreground: foregroundColor, background: backgroundColor)
#if os(Windows)
        let stderr = GetStdHandle(STD_ERROR_HANDLE)!
#endif
        return OutputStream(file: stderr, color: colors, style: style)
    }

    public static func standardOutput(
        foregroundColor: Color? = nil,
        backgroundColor: Color? = nil,
        style: Style = Style(rawValue: 0)
    ) -> OutputStream
    {
        let colors = Colors(foreground: foregroundColor, background: backgroundColor)
#if os(Windows)
        let stdout = GetStdHandle(STD_OUTPUT_HANDLE)!
#endif
        return OutputStream(file: stdout, color: colors, style: style)
    }

    // MARK: - Public computed properties
    public var style: Style {
        get {
            self.styleStorage
        }

        set {
            self.requiresStyleFlushNextTime = true
            self.styleStorage = newValue
        }
    }

    public var color: Colors {
        get {
            self.colorStorage
        }

        set {
            self.requiresStyleFlushNextTime = true
            self.colorStorage = newValue
        }
    }

    // MARK: - Public computed methods

    public mutating func write(_ string: String) {
        if self.requiresStyleFlushNextTime {
#if os(Windows)
            if self.styling != .none, let newAttributes = self.color.windowsConsoleAttributesValue {
                SetConsoleTextAttribute(self.file, newAttributes)
            }
#endif
            if self.shouldOutputANSI {
#if os(Windows)
                WriteFile(
                    self.file,
                    self.ansi,
                    DWORD(self.ansi.utf8.count),
                    nil,
                    nil
                )

#else
                fputs(self.ansi, self.file)
#endif
            }

            self.requiresStyleFlushNextTime = false
        }

#if os(Windows)
        WriteFile(
            self.file,
            string,
            DWORD(string.utf8.count),
            nil,
            nil
        )
#else
        fputs(string, self.file)
#endif
    }

    public mutating func clear() {
        if self.shouldOutputANSI {
            print("\u{001B}[0m", terminator: "", to: &self)
        }

#if os(Windows)
        SetConsoleTextAttribute(self.file, self.originalConsoleAttributes)
#endif
        self.colorStorage = Colors(foreground: nil, background: nil)
        self.style = Style(rawValue: 0)
    }

    public mutating func write(_ segments: (String, [StyleSegment])...) {
        self.write(segments)
    }

    public mutating func write(_ segments: [(String, [StyleSegment])]) {
        for segment in segments {
            let (text, options) = segment
            var foreground: Color?
            var background: Color?
            var styleOption: Style = []

            for option in options {
                switch option {
                case .foreground(let color):
                    foreground = color
                case .background(let color):
                    background = color
                case .style(let style):
                    styleOption = style
                }
            }

            if styleOption.isEmpty {
                self.clear()
            }

            self.color.foreground = foreground
            self.color.background = background
            self.style = styleOption

            print(text, terminator: "", to: &self)
        }

        self.clear()
    }

    // MARK: - Private methods

    private init(file: NativeFileHandle, color: Colors, style: Style) {
        var consoleInfo = CONSOLE_SCREEN_BUFFER_INFO()
        GetConsoleScreenBufferInfo(file, &consoleInfo)
        self.originalConsoleAttributes = consoleInfo.wAttributes
        self.file = file
        self.requiresStyleFlushNextTime = color.foreground != nil || color.background != nil || style != []
        self.color = color
        self.style = style
    }

    private var shouldOutputANSI: Bool {
        switch self.styling {
        case .none:
            return false
        case .ansi:
            return true
        case .auto:
#if os(Windows)
            let fileIsTTY = FILE_TYPE_CHAR == GetFileType(self.file)
            let platformIsFriendly = false
#else
            let fileIsTTY = 1 == isatty(fileno(self.file))
            let platformIsFriendly = true
#endif

            return fileIsTTY && platformIsFriendly
        }
    }

    private var ansi: String {
        if self.color.foreground == nil && self.color.background == nil && self.style == [] {
            return "\u{001B}[0m"
        }

        var result = "\u{001B}["
        var codeStrings: [String] = []
        if let color = self.color.foreground?.ansiValue {
            codeStrings.append("38")
            codeStrings.append("5")
            codeStrings.append("\(color)")
        }

        if let color = self.color.background?.ansiValue {
            codeStrings.append("48")
            codeStrings.append("5")
            codeStrings.append("\(color)")
        }

        let lookups: [(Style, Int)] = [(.bold, 1), (.dim, 2), (.italic, 3), (.underlined, 4), (.blink, 5), (.inverse, 7), (.hidden, 8), (.strikethrough, 9)]
        for (key, value) in lookups where style.contains(key) {
            codeStrings.append(String(value))
        }

        result += codeStrings.joined(separator: ";")
        result += "m"
        return result
    }

    public enum Styling: Equatable {
        case auto
        case ansi
        case none
    }

    public enum Color {
        case black
        case red
        case green
        case yellow
        case blue
        case magenta
        case cyan
        case white
        case ansi(UInt8)

        public init?(ansiValue: UInt8) {
            switch ansiValue {
            case 0: self = .black
            case 1: self = .red
            case 2: self = .green
            case 3: self = .yellow
            case 4: self = .blue
            case 5: self = .magenta
            case 6: self = .cyan
            case 7: self = .white
            default: self = .ansi(ansiValue)
            }
        }

        public var ansiValue: UInt8 {
            switch self {
            case .black: return 0
            case .red: return 1
            case .green: return 2
            case .yellow: return 3
            case .blue: return 4
            case .magenta: return 5
            case .cyan: return 6
            case .white: return 7
            case .ansi(let number): return number
            }
        }
    }

    public struct Colors {
        public var foreground: Color?
        public var background: Color?

#if os(Windows)
        var windowsConsoleAttributesValue: WORD? {
            if self.foreground == nil && self.background == nil {
                return nil
            }

            var attributes: Int32 = 0

            switch self.foreground {
            case .black:
                break
            case .red:
                attributes |= FOREGROUND_RED
            case .green:
                attributes |= FOREGROUND_GREEN
            case .yellow:
                attributes |= FOREGROUND_GREEN | FOREGROUND_RED
            case .blue:
                attributes |= FOREGROUND_BLUE
            case .magenta:
                attributes |= FOREGROUND_BLUE | FOREGROUND_RED
            case .cyan:
                attributes |= FOREGROUND_BLUE | FOREGROUND_GREEN
            case .white:
                attributes |= FOREGROUND_BLUE | FOREGROUND_GREEN | FOREGROUND_RED
            case nil, .ansi:
                break
            }

            switch self.background {
            case .black:
                break
            case .red:
                attributes |= BACKGROUND_RED
            case .green:
                attributes |= BACKGROUND_GREEN
            case .yellow:
                attributes |= BACKGROUND_GREEN | BACKGROUND_RED
            case .blue:
                attributes |= BACKGROUND_BLUE
            case .magenta:
                attributes |= BACKGROUND_BLUE | BACKGROUND_RED
            case .cyan:
                attributes |= BACKGROUND_BLUE | BACKGROUND_GREEN
            case .white:
                attributes |= BACKGROUND_BLUE | BACKGROUND_GREEN | BACKGROUND_RED
            case nil, .ansi:
                break
            }

            return WORD(attributes)
        }
#endif
    }

    public struct Style: OptionSet {
        public static let bold = Style(rawValue: 1 << 0)
        public static let dim = Style(rawValue: 1 << 1)
        public static let italic = Style(rawValue: 1 << 2)
        public static let underlined = Style(rawValue: 1 << 3)
        public static let blink = Style(rawValue: 1 << 4)
        public static let inverse = Style(rawValue: 1 << 5)
        public static let hidden = Style(rawValue: 1 << 6)
        public static let strikethrough = Style(rawValue: 1 << 7)

        public let rawValue: Int

        public init(rawValue: Int) {
            self.rawValue = rawValue
        }
    }

    public enum StyleSegment {
        case foreground(Color)
        case background(Color)
        case style(Style)
    }
}
