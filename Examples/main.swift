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
// platforms.
stream.clear()
print("!")


// The following produces the same result as the above but with a syntax-sugar
// API.
stream.write(
    ("black   ",    [.foreground(.white), .background(.black)]  ),
    ("red     ",    [.foreground(.blue), .background(.red)]     ),
    ("green   ",    [.foreground(.magenta), .background(.green)]),
    ("yellow  ",    [.foreground(.red), .background(.yellow)]   ),
    ("blue    ",    [.foreground(.yellow), .background(.blue)]  ),
    ("magenta ",    [.foreground(.green), .background(.magenta)]),
    ("cyan    ",    [.foreground(.black), .background(.cyan)]   ),
    ("white   ",    [.foreground(.cyan), .background(.white)]   ),
    ("\n",          []                                          )
)
// Note with this API, `.clear()` is invoked automatically at the end.

// The above API can also take in a array, it's more useful if you need to
// generate styled output else where (to make it testable, for example).
var segments = [(String, [OutputStream.StyleSegment])]()
for foreground in UInt8(0)..<8 {
    for background in UInt8(0)..<8 {
        segments.append(
            (
                "\(foreground)\(background)",
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
