import Darwin.C.stdio

public struct OutputStream: TextOutputStream {
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

    private var colorStorage = Colors(foreground: nil, background: nil)
    private var styleStorage = Style(rawValue: 0)
    private var requiresStyleFlushNextTime = false

    private var shouldOutputANSI: Bool {
        let fileIsTTY = 1 == isatty(fileno(self.file))
        return self.styling != .none && fileIsTTY || self.styling == .ansi
    }

    public var styling: Styling = .auto

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

    private var file: UnsafeMutablePointer<FILE>

    init(file: UnsafeMutablePointer<FILE>, color: Colors, style: Style) {
        self.file = file
        self.requiresStyleFlushNextTime = color.foreground != nil || color.background != nil || style != []
        self.color = color
        self.style = style
    }

    public static func standardError(foregroundColor: Color? = nil, backgroundColor: Color? = nil, style: Style = Style(rawValue: 0)) -> OutputStream {
        let colors = Colors(foreground: foregroundColor, background: backgroundColor)
        return OutputStream(file: stderr, color: colors, style: style)
    }

    public static func standardOutput(foregroundColor: Color? = nil, backgroundColor: Color? = nil, style: Style = Style(rawValue: 0)) -> OutputStream {
        let colors = Colors(foreground: foregroundColor, background: backgroundColor)
        return OutputStream(file: stdout, color: colors, style: style)
    }

    public mutating func write(_ string: String) {
        if self.requiresStyleFlushNextTime {
            if self.shouldOutputANSI {
                fputs(self.ansi, self.file)
            }
            self.requiresStyleFlushNextTime = false
        }

        fputs(string, self.file)
    }

    var ansi: String {
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

    public mutating func clear() {
        print("\u{001B}[0m", terminator: "", to: &self)
        self.colorStorage = Colors(foreground: nil, background: nil)
        self.style = Style(rawValue: 0)
    }

    public enum StyleSegment {
        case foreground(Color)
        case background(Color)
        case style(Style)
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
    }
}

