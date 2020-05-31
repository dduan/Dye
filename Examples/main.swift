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
stream.clear()
print("!")


// The following produces the same result as the above but with a syntax-sugar
// API.
stream.write(
    ("Hello, ",    []                                      ),
    ("Terminal",   [.foreground(.red), .style(.underlined)]),
    ("!\n",        []                                      ),
    ("black\t", [.background(.black)]),
    ("red\t", [.background(.red)]),
    ("green\t", [.background(.green)]),
    ("yellow\t", [.background(.yellow)]),
    ("blue\t", [.background(.blue)]),
    ("magenta\t", [.background(.magenta)]),
    ("cyan\t", [.background(.cyan)]),
    ("white\t", [.background(.white)])
)
stream.clear()
