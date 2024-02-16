import SwiftUI

indirect enum Doc {
    case empty
    case text(String)
    case sequence(Doc, Doc)
    case newline
    case indent(Doc)
    case choice(Doc, Doc) // left is widest doc
}

struct PrettyState {
    var columnWidth: Int
    var stack: [(indentation: Int, Doc)]
    var tabWidth = 4
    var currentColumn = 0

    init(columnwidth: Int, doc: Doc) {
        self.columnWidth = columnwidth
        self.stack = [(0, doc)]
    }

    mutating func render() -> String {
        guard let (indentation, el) = stack.popLast() else { return "" }
        switch el {
        case .empty:
            return "" + render()
        case .text(let string):
            currentColumn += string.count
            return string + render()
        case .sequence(let doc, let doc2):
            stack.append((indentation, doc2))
            stack.append((indentation, doc))
            return render()
        case .newline:
            let spaces = indentation * tabWidth
            currentColumn = spaces
            return "\n" + String(repeating: " ", count: spaces) + render()
        case .indent(let doc):
            stack.append((indentation + 1, doc))
            return render()
        case .choice(let doc, let doc2):
            let copy = self
            stack.append((indentation, doc))
            let attempt = render()
            if attempt.fits(width: columnWidth-copy.currentColumn) {
                return attempt
            } else {
                self = copy
                stack.append((indentation, doc2))
                return render()
            }
        }
    }
}

extension String {
    func fits(width: Int) -> Bool {
        prefix { !$0.isNewline }.count <= width
    }
}

extension Doc {
    func flatten() -> Doc {
        switch self {
        case .empty:
            .empty
        case .text(let string):
            self
        case .sequence(let doc, let doc2):
            .sequence(doc.flatten(), doc2.flatten())
        case .newline:
            .text(" ")
        case .indent(let doc):
            .indent(doc.flatten())
        case .choice(let doc, _):
            doc
        }
    }

    func group() -> Doc {
        .choice(flatten(), self)
    }
}


extension Doc {
    func pretty(columns: Int) -> String {
        var state = PrettyState(columnwidth: columns, doc: self)
        return state.render()
    }

    static func +(lhs: Doc, rhs: Doc) -> Doc {
        .sequence(lhs, rhs)
    }
}

let arguments: Doc = .text("aLongerArgument: 1,") + .indent(.newline + .text("bar: true"))

let doc: Doc = .text("func hello(") + arguments.group() + .text(") {") + .indent(.newline + .text("print(\"Hello\")")) + .newline + .text("}")

struct ContentView: View {
    @State var width = 20.0
    var body: some View {
        VStack {
            VStack(alignment: .leading) {
                Text(String(repeating: ".", count: Int(width)))
                Text(doc.pretty(columns: Int(width)))
                    .fixedSize()
            }
            Spacer()
            Slider(value: $width, in: 0...80)
        }
        .monospaced()
        .padding()
    }
}

#Preview {
    ContentView()
}
