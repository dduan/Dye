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
print("!", terminator: "\n\n")

// You can pair text segments with their desired style with a batch-writing API:
// Note with this API, `.clear()` is invoked automatically at the end.
stream.write(
    ("black   ",    [.foreground(OutputStream.Color.black  .intensified), .background(.black  )]),
    ("red     ",    [.foreground(OutputStream.Color.red    .intensified), .background(.red    )]),
    ("green   ",    [.foreground(OutputStream.Color.green  .intensified), .background(.green  )]),
    ("yellow  ",    [.foreground(OutputStream.Color.yellow .intensified), .background(.yellow )]),
    ("blue    ",    [.foreground(OutputStream.Color.blue   .intensified), .background(.blue   )]),
    ("magenta ",    [.foreground(OutputStream.Color.magenta.intensified), .background(.magenta)]),
    ("cyan    ",    [.foreground(OutputStream.Color.cyan   .intensified), .background(.cyan   )]),
    ("white   ",    [.foreground(OutputStream.Color.white  .intensified), .background(.white  )]),
    ("\n\n",        [                                                                          ])
)

// The above API can also take in a array, it's more useful if you need to
// generate styled output else where (to make it testable, for example).
var segments = [(String, [OutputStream.StyleSegment])]()
for foreground in UInt8(8)..<16 {
    for background in UInt8(0)..<8 {
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
