import Dye

// A stream holds the original and current state regarding colors and style of
// the text that's going to be printed to the terminal.
var stream = OutputStream.standardOutput()

// We can set the color and/or style for the text and clear them to reset to
// the original state when the stream instance is created. Then use it as a
// normal `TextOutputStream`(https://developer.apple.com/documentation/swift/textoutputstream).
print("Hello, ", terminator: "")
stream.color.foreground = .red
stream.style = .underlined
print("Terminal", terminator: "", to: &stream)
// Remember to call this so that your terminal resets to the state it began with. This is important in certain
// terminal simulators (e.g. Windows Command Prompt).
stream.clear()
print("!", terminator: "\n\n")

// You can pair text segments with their desired style with a batch-writing API:
// Note with this API, `.clear()` is invoked automatically at the end.
//
// Each of the 8 primary colors has a "intense" version. The 2 versions can be converted to each other. For
// example, `OutputStream.Color.red.intensified.softened` converts red to intense red and back.
stream.write(
    ("black   ",    [.foreground(.intenseBlack  ), .background(.black  )]),
    ("red     ",    [.foreground(.intenseRed    ), .background(.red    )]),
    ("green   ",    [.foreground(.intenseGreen  ), .background(.green  )]),
    ("yellow  ",    [.foreground(.intenseYellow ), .background(.yellow )]),
    ("blue    ",    [.foreground(.intenseBlue   ), .background(.blue   )]),
    ("magenta ",    [.foreground(.intenseMagenta), .background(.magenta)]),
    ("cyan    ",    [.foreground(.intenseCyan   ), .background(.cyan   )]),
    ("white   ",    [.foreground(.intenseWhite  ), .background(.white  )])
)

print("", terminator: "\n\n")

// The above API can also take in a array, it's more useful if you need to
// generate styled output else where (to make it testable, for example).
var segments = [(String, [OutputStream.StyleSegment])]()
for foreground in UInt8(8)..<16 { // intense color for forground
    for background in UInt8(0)..<8 { // normal color for background
        segments.append(
            (
                "\(String(foreground, radix: 16))\(String(background, radix: 16))",
                [
                    .foreground(OutputStream.Color(ansiValue: foreground)!),
                    .background(OutputStream.Color(ansiValue: background)!),
                ]
            )
        )
    }

    segments.append(("\n", []))
}

stream.write(segments)
