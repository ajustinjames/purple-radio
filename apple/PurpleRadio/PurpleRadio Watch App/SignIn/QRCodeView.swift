import SwiftUI

/// Draws a `QRCode` as black modules on white, with the quiet zone scanners need.
struct QRCodeView: View {
    let code: QRCode
    /// The standard quiet zone is four modules; two scans reliably from a phone held
    /// close to the watch and leaves more room for the code.
    var quietZone = 2

    var body: some View {
        Canvas { context, size in
            let count = code.size + quietZone * 2
            let module = min(size.width, size.height) / CGFloat(count)
            context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(.white))
            var path = Path()
            for row in 0..<code.size {
                for column in 0..<code.size where code[row, column] {
                    path.addRect(CGRect(
                        x: CGFloat(column + quietZone) * module,
                        y: CGFloat(row + quietZone) * module,
                        width: module,
                        height: module
                    ))
                }
            }
            context.fill(path, with: .color(.black))
        }
        .aspectRatio(1, contentMode: .fit)
        .clipShape(.rect(cornerRadius: 8))
        .accessibilityLabel("Sign-in QR code")
    }
}

#Preview {
    QRCodeView(code: try! QRCode(text: "https://www.twitch.tv/activate?public=true&device-code=ABCDEFGH"))
        .frame(width: 120)
}
