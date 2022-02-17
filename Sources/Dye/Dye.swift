#if os(macOS)
import Darwin
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

/// `OutputStream` is the primary interface for styles of your text output in terminal applications. It holds
/// states for upcoming outputs, as well as those needed to restore to the terminal to its original state (in
/// stateful terminal simulators such as CMD.EXE on Windows).
///
/// `OutputStream` conforms to `Swift.TextOutputStream`, which works with Swift's `print` function:
///
/// ```swift
/// var outputStream = OutputStream.standardOutput()
/// print("Hello, ", to: &outputStream)
/// ```
///
/// To make the upcoming text in red, and bold text in the terminal, for example, do this:
///
/// ```swift
/// outputStream.color.foreground = .red
/// outputStream.style = .bold
/// print("world", to: &outputStream) // "world" will be in red and bold text.
/// ```
///
/// When you need to restore the output to the original style, use `OutputStream.clear()`. This is important
/// to not leave some terminal apps in the style your app last used, after it exits:
///
/// ```swift
/// outputStream.clear()
/// print("!") // this will be in the old style before `outputStream` was created.
/// ```
///
/// There's also another, more streamlined way to pair segments of output with different styles. The following
/// code accomplishes the same thing as previous examples.
///
/// ```swift
/// outputStream.write(
///     ("Hello, ", []),
///     ("world", [.foreground(.red), .style(.bold)]),
/// )
/// print("!") // note we don't need to manually clear the terminal with this API.
/// ```
public struct OutputStream: TextOutputStream {
    // MARK: - Public stored properties

    /// Whether to disable styling automatically, always emit ANSI escape codes, or disable styling always.
    /// Read documentation for `StylingMethod` to learn more.
    public var stylingMethod: StylingMethod = .auto

    // MARK: - Public static functions

    /// Create a stream that writes to `stderr`.
    ///
    /// - Parameters:
    ///   - foregroundColor: the color for the upcoming text output.
    ///   - backgroundColor: the background color for the upcoming text output.
    ///   - style:           other styles you want to apply to text output. This has no effect for some older
    ///                      terminal simulators on Windows, such as CMD.EXE
    ///
    /// - Returns: A stream for stderr.
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

    /// Create a stream that writes to `stdout`.
    ///
    /// - Parameters:
    ///   - foregroundColor: the color for the upcoming text output.
    ///   - backgroundColor: the background color for the upcoming text output.
    ///   - style:           other styles you want to apply to text output. This has no effect for some older
    ///                      terminal simulators on Windows, such as CMD.EXE
    ///
    /// - Returns: A stream for stdout.
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

    /// Attributes of the text other than colors. Such as bold/italic text, underline, etc. Many styles can be
    /// composed as this value is an `OptionSet`. Whether a style gets rendered is up to the terminal
    /// simulator's settings and implementation.
    public var style: Style {
        get {
            self.styleStorage
        }

        set {
            self.requiresStyleFlushNextTime = true
            self.styleStorage = newValue
        }
    }

    /// Colors for the upcoming text output. Foreground color is the color of the text itself. Background
    /// color is the color for the space behind the text.
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

    /// Produce text output in the stream. This is required to conform to `TextOutputStream`.
    ///
    /// - Parameter string: the text to produce in the stream.
    public mutating func write(_ string: String) {
        if self.requiresStyleFlushNextTime {
#if os(Windows)
            if self.stylingMethod != .none && !self.isNoColorVariableSet,
                let newAttributes = self.color.windowsConsoleAttributesValue
            {
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

    /// Reset the stream to the state prior to creation of this instance, restoring the colors and style of
    /// text.
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

    /// Output segments of text paired with desired colors and styles for each.
    ///
    /// - Parameter segments: list of text-style pairs to output.
    public mutating func write(_ segments: (String, [StyleSegment])...) {
        self.write(segments)
    }

    /// Output segments of text paired with desired colors and styles for each.
    ///
    /// - Parameter segments: list of text-style pairs to output.
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

    // MARK: - Nested Public Types

    /// Dye may attempt to style text in a few ways. On Unix, this maybe be accomplished by inserting
    /// additional [ANSI escape codes](https://en.wikipedia.org/wiki/ANSI_escape_code) surrounding the actual
    /// text. On Windows, some console-specific API is used to control the output style. In addition, Dye can
    /// detect the output is not a terminal and therefore avoid producing the escape sequences.
    ///
    /// All of these methods can be controlled by this option.
    ///
    /// In addition, Dye respects the `NO_COLOR` [convention](no-color.org). If this environment variable
    /// exists, styling is disabled.
    public enum StylingMethod: Equatable {
        /// Disable styling when the output device is not a terminal (e.g, Unix pipe). Otherwise use the
        /// default methods to style terminal output.
        case auto
        /// Always output ANSI escape code. On Windows, this means the console API is invoked as well. Some
        /// modern terminal simulators on Windows can render ANSI escape code properly. But Command Prompt,
        /// notably, does not.
        case ansi
        /// Disable any attempt to render colors or style.
        case none
    }

    /// Color for the output text. Extended colors may be used with the `.ansi` value, such value will be
    /// ignored when ANSI escape code is not used (default on Windows).
    ///
    /// Each of the first 8 color has a complimentary, *intense* version. The two maybe converted to each
    /// other with `.intensified` and `.softened`.
    public enum Color {
        case black
        case red
        case green
        case yellow
        case blue
        case magenta
        case cyan
        case white
        case intenseBlack
        case intenseRed
        case intenseGreen
        case intenseYellow
        case intenseBlue
        case intenseMagenta
        case intenseCyan
        case intenseWhite
        case ansi(UInt8)

        /// Create a color from its corresponding ANSI code.
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
            case 8: self =  .intenseBlack
            case 9: self =  .intenseRed
            case 10: self = .intenseGreen
            case 11: self = .intenseYellow
            case 12: self = .intenseBlue
            case 13: self = .intenseMagenta
            case 14: self = .intenseCyan
            case 15: self = .intenseWhite
            default: self = .ansi(ansiValue)
            }
        }

        /// Convert softened color (0-7) to its intense counterpart. If it's not 0-7, return the color
        /// unchanged.
        public var intensified: Color {
            switch self {
            case .black: return .intenseBlack
            case .red: return .intenseRed
            case .green: return .intenseGreen
            case .yellow: return .intenseYellow
            case .blue: return .intenseBlue
            case .magenta: return .intenseMagenta
            case .cyan: return .intenseCyan
            case .white: return .intenseWhite
            default: return self
            }
        }

        /// Convert intense color (8-15) to its softened counterpart. If it's not 8-15, return the color
        /// unchanged.
        public var softened: Color {
            switch self {
            case .intenseBlack: return .black
            case .intenseRed: return .red
            case .intenseGreen: return .green
            case .intenseYellow: return .yellow
            case .intenseBlue: return .blue
            case .intenseMagenta: return .magenta
            case .intenseCyan: return .cyan
            case .intenseWhite: return .white
            default: return self
            }
        }
    }

    /// Two colors, representing the foreground and background.
    public struct Colors {
        /// The foreground color.
        public var foreground: Color?
        /// The background color.
        public var background: Color?
    }

    /// Text styles. These can be combined as expected for an `OptionSet`. Not all terminal simulators render
    /// all of these styles. On Windows, these have no effect to terminals that don't support ANSI escape
    /// codes.
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

    /// Represents an aspect of text output customization. It's expected to be used in an array with the
    /// batch write APIs:
    ///
    /// ```swift
    /// stream.write(
    ///   ("Hello, ", []),
    ///   ("World", [.foreground(.red)]),
    ///   ("!", []),
    /// )
    /// ```
    /// This code prints out "Hello, World!" with "World" being red.
    public enum StyleSegment {
        /// Set the foreground color
        case foreground(Color)
        /// Set the background color
        case background(Color)
        /// Set the style.
        case style(Style)
    }

    // MARK: - Private stored properties

    private var file: NativeFileHandle
    private var colorStorage = Colors(foreground: nil, background: nil)
    private var styleStorage = Style(rawValue: 0)
    private var requiresStyleFlushNextTime = false
#if os(Windows)
    private let originalConsoleAttributes: WORD
#endif

    private let isNoColorVariableSet: Bool = {
#if os(Windows)
        var ptr = UnsafeMutablePointer<CChar>(bitPattern: 0)
        _dupenv_s(&ptr, nil, "NO_COLOR")
        let noColor = ptr != nil
        free(ptr)
        return noColor
#else
        return getenv("NO_COLOR") != nil
#endif
    }()

    // MARK: - Private methods

    private init(file: NativeFileHandle, color: Colors, style: Style) {
#if os(Windows)
        var consoleInfo = CONSOLE_SCREEN_BUFFER_INFO()
        GetConsoleScreenBufferInfo(file, &consoleInfo)
        self.originalConsoleAttributes = consoleInfo.wAttributes
#endif
        self.file = file
        self.requiresStyleFlushNextTime = color.foreground != nil || color.background != nil || style != []
        self.color = color
        self.style = style
    }

    private var shouldOutputANSI: Bool {
        switch self.stylingMethod {
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
            return fileIsTTY && platformIsFriendly && !self.isNoColorVariableSet
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

        let lookups: [(Style, Int)] = [
            (.bold, 1),
            (.dim, 2),
            (.italic, 3),
            (.underlined, 4),
            (.blink, 5),
            (.inverse, 7),
            (.hidden, 8),
            (.strikethrough, 9)
        ]
        for (key, value) in lookups where style.contains(key) {
            codeStrings.append(String(value))
        }

        result += codeStrings.joined(separator: ";")
        result += "m"
        return result
    }
}

private extension OutputStream.Color {
    var ansiValue: UInt8 {
        switch self {
        case .black: return 0
        case .red: return 1
        case .green: return 2
        case .yellow: return 3
        case .blue: return 4
        case .magenta: return 5
        case .cyan: return 6
        case .white: return 7
        case .intenseBlack: return 8
        case .intenseRed: return 9
        case .intenseGreen: return 10
        case .intenseYellow: return 11
        case .intenseBlue: return 12
        case .intenseMagenta: return 13
        case .intenseCyan: return 14
        case .intenseWhite: return 15
        case .ansi(let number): return number
        }
    }
}

#if os(Windows)
private extension OutputStream.Colors {
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
        case .intenseBlack:
            attributes |= FOREGROUND_INTENSITY
        case .intenseRed:
            attributes |= FOREGROUND_RED | FOREGROUND_INTENSITY
        case .intenseGreen:
            attributes |= FOREGROUND_GREEN | FOREGROUND_INTENSITY
        case .intenseYellow:
            attributes |= FOREGROUND_GREEN | FOREGROUND_RED | FOREGROUND_INTENSITY
        case .intenseBlue:
            attributes |= FOREGROUND_BLUE | FOREGROUND_INTENSITY
        case .intenseMagenta:
            attributes |= FOREGROUND_BLUE | FOREGROUND_RED | FOREGROUND_INTENSITY
        case .intenseCyan:
            attributes |= FOREGROUND_BLUE | FOREGROUND_GREEN | FOREGROUND_INTENSITY
        case .intenseWhite:
            attributes |= FOREGROUND_BLUE | FOREGROUND_GREEN | FOREGROUND_RED | FOREGROUND_INTENSITY
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
        case .intenseBlack:
            attributes |= BACKGROUND_INTENSITY
        case .intenseRed:
            attributes |= BACKGROUND_RED | BACKGROUND_INTENSITY
        case .intenseGreen:
            attributes |= BACKGROUND_GREEN | BACKGROUND_INTENSITY
        case .intenseYellow:
            attributes |= BACKGROUND_GREEN | BACKGROUND_RED | BACKGROUND_INTENSITY
        case .intenseBlue:
            attributes |= BACKGROUND_BLUE | BACKGROUND_INTENSITY
        case .intenseMagenta:
            attributes |= BACKGROUND_BLUE | BACKGROUND_RED | BACKGROUND_INTENSITY
        case .intenseCyan:
            attributes |= BACKGROUND_BLUE | BACKGROUND_GREEN | BACKGROUND_INTENSITY
        case .intenseWhite:
            attributes |= BACKGROUND_BLUE | BACKGROUND_GREEN | BACKGROUND_RED | BACKGROUND_INTENSITY
        case nil, .ansi:
            break
        }

        return WORD(attributes)
    }
}
#endif
