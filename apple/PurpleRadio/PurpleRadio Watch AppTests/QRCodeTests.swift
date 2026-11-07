import Testing
@testable import PurpleRadio_Watch_App

struct QRCodeTests {
    /// The 1-M example message and its error correction codewords from the QR
    /// specification's worked example.
    @Test func reedSolomonMatchesReferenceExample() {
        let data: [UInt8] = [32, 91, 11, 120, 209, 114, 220, 77, 67, 64, 236, 17, 236, 17, 236, 17]
        #expect(ReedSolomon.remainder(of: data, degree: 10) == [196, 35, 39, 119, 235, 215, 231, 226, 93, 23])
    }

    @Test func formatBitsMatchReferenceTable() {
        #expect(QRCode.formatBits(mask: 0) == 0b101010000010010)
        #expect(QRCode.formatBits(mask: 5) == 0b100000011001110)
        #expect(QRCode.formatBits(mask: 7) == 0b100101010100000)
    }

    @Test func versionBitsMatchReferenceTable() {
        #expect(QRCode.versionBits(7) == 0b000111110010010100)
        #expect(QRCode.versionBits(10) == 0b001010010011010011)
    }

    @Test(arguments: [(1, 21), (62, 33), (63, 37), (84, 37), (213, 57)])
    func picksSmallestVersionThatFits(length: Int, size: Int) throws {
        let code = try QRCode(text: String(repeating: "x", count: length))
        #expect(code.size == size)
        #expect(code.modules.count == size * size)
    }

    @Test func rejectsTextBeyondVersion10() {
        #expect(throws: QRCode.EncodingError.tooLong) {
            try QRCode(text: String(repeating: "x", count: 214))
        }
    }

    @Test func drawsFinderPatternsInThreeCorners() throws {
        let code = try QRCode(text: "https://www.twitch.tv/activate?public=true&device-code=ABCDEFGH")
        let last = code.size - 1
        for (row, column) in [(0, 0), (0, last - 6), (last - 6, 0)] {
            #expect(code[row, column] && code[row + 6, column + 6])  // Outer ring corners.
            #expect(!code[row + 1, column + 1])  // Light ring.
            #expect(code[row + 3, column + 3])  // Center.
        }
        #expect(code[code.size - 8, 8])  // Always-dark module.
    }
}
