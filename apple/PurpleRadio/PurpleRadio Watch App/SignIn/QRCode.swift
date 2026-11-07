/// A QR code symbol for a short piece of text, such as the sign-in verification URL.
///
/// Core Image isn't in the watchOS SDK, so the app encodes QR codes itself. This encoder
/// covers only what sign-in needs: byte mode, error correction level M, and versions 1–10
/// (up to 213 bytes). It follows ISO/IEC 18004, including penalty-based mask selection.
nonisolated struct QRCode: Sendable, Equatable {
    /// Modules per side, without the quiet zone.
    let size: Int
    /// Row-major; `true` is a dark module.
    let modules: [Bool]

    subscript(row: Int, column: Int) -> Bool {
        modules[row * size + column]
    }

    enum EncodingError: Error, Equatable {
        case tooLong
    }

    /// Encodes `text` as UTF-8 bytes in the smallest version that fits.
    init(text: String) throws {
        let bytes = Array(text.utf8)
        guard let version = Spec.versions.first(where: { $0.byteCapacity >= bytes.count }) else {
            throw EncodingError.tooLong
        }
        let codewords = QRCode.codewords(for: bytes, version: version)
        var grid = Grid(version: version)
        grid.placeData(codewords)

        var best: Grid?
        var bestPenalty = Int.max
        for mask in 0..<8 {
            var candidate = grid
            candidate.applyMask(mask)
            candidate.drawFormatBits(mask: mask)
            let penalty = candidate.penalty()
            if penalty < bestPenalty {
                best = candidate
                bestPenalty = penalty
            }
        }
        size = grid.size
        modules = best!.dark
    }

    // MARK: - Codewords

    /// Data codewords followed by error correction codewords, interleaved across blocks.
    private static func codewords(for bytes: [UInt8], version: Spec.Version) -> [UInt8] {
        var bits = BitBuffer()
        bits.append(0b0100, count: 4)  // Byte mode.
        bits.append(bytes.count, count: version.number < 10 ? 8 : 16)
        for byte in bytes { bits.append(Int(byte), count: 8) }

        let capacityBits = version.dataCodewords * 8
        bits.append(0, count: min(4, capacityBits - bits.count))  // Terminator.
        bits.append(0, count: (8 - bits.count % 8) % 8)
        var data = bits.bytes
        var pad: UInt8 = 0xEC
        while data.count < version.dataCodewords {
            data.append(pad)
            pad = pad == 0xEC ? 0x11 : 0xEC
        }

        var blocks: [[UInt8]] = []
        var offset = 0
        for length in version.blockLengths {
            blocks.append(Array(data[offset..<offset + length]))
            offset += length
        }
        let correction = blocks.map { ReedSolomon.remainder(of: $0, degree: version.eccPerBlock) }

        var result: [UInt8] = []
        for index in 0..<(version.blockLengths.max() ?? 0) {
            for block in blocks where index < block.count { result.append(block[index]) }
        }
        for index in 0..<version.eccPerBlock {
            for block in correction { result.append(block[index]) }
        }
        return result
    }

    /// The 15-bit format information for level M and `mask`, before placement.
    static func formatBits(mask: Int) -> Int {
        let data = (0b00 << 3) | mask  // Level M is 00.
        var remainder = data
        for _ in 0..<10 { remainder = (remainder << 1) ^ ((remainder >> 9) * 0x537) }
        return ((data << 10) | remainder) ^ 0x5412
    }

    /// The 18-bit version information, used from version 7.
    static func versionBits(_ version: Int) -> Int {
        var remainder = version
        for _ in 0..<12 { remainder = (remainder << 1) ^ ((remainder >> 11) * 0x1F25) }
        return (version << 12) | remainder
    }
}

// MARK: - Specification tables

nonisolated private enum Spec {
    struct Version {
        let number: Int
        let eccPerBlock: Int
        /// Data codewords in each block, shorter blocks first.
        let blockLengths: [Int]
        let alignmentCenters: [Int]

        var dataCodewords: Int { blockLengths.reduce(0, +) }
        var size: Int { number * 4 + 17 }
        /// Mode indicator and character count take 12 bits below version 10, 20 from it.
        var byteCapacity: Int { (dataCodewords * 8 - (number < 10 ? 12 : 20)) / 8 }
    }

    /// Error correction level M, versions 1–10.
    static let versions: [Version] = [
        Version(number: 1, eccPerBlock: 10, blockLengths: [16], alignmentCenters: []),
        Version(number: 2, eccPerBlock: 16, blockLengths: [28], alignmentCenters: [6, 18]),
        Version(number: 3, eccPerBlock: 26, blockLengths: [44], alignmentCenters: [6, 22]),
        Version(number: 4, eccPerBlock: 18, blockLengths: [32, 32], alignmentCenters: [6, 26]),
        Version(number: 5, eccPerBlock: 24, blockLengths: [43, 43], alignmentCenters: [6, 30]),
        Version(number: 6, eccPerBlock: 16, blockLengths: [27, 27, 27, 27], alignmentCenters: [6, 34]),
        Version(number: 7, eccPerBlock: 18, blockLengths: [31, 31, 31, 31], alignmentCenters: [6, 22, 38]),
        Version(number: 8, eccPerBlock: 22, blockLengths: [38, 38, 39, 39], alignmentCenters: [6, 24, 42]),
        Version(number: 9, eccPerBlock: 22, blockLengths: [36, 36, 36, 37, 37], alignmentCenters: [6, 26, 46]),
        Version(number: 10, eccPerBlock: 26, blockLengths: [43, 43, 43, 43, 44], alignmentCenters: [6, 28, 50]),
    ]
}

// MARK: - Bits and Reed–Solomon

nonisolated private struct BitBuffer {
    private(set) var bits: [Bool] = []
    var count: Int { bits.count }

    mutating func append(_ value: Int, count: Int) {
        for shift in stride(from: count - 1, through: 0, by: -1) {
            bits.append((value >> shift) & 1 == 1)
        }
    }

    var bytes: [UInt8] {
        stride(from: 0, to: bits.count, by: 8).map { start in
            bits[start..<start + 8].reduce(0) { ($0 << 1) | ($1 ? 1 : 0) }
        }
    }
}

nonisolated enum ReedSolomon {
    /// Multiplies in GF(2^8) with the QR code polynomial x^8 + x^4 + x^3 + x^2 + 1.
    static func multiply(_ a: UInt8, _ b: UInt8) -> UInt8 {
        var result = 0
        var a = Int(a)
        var b = Int(b)
        while b > 0 {
            if b & 1 == 1 { result ^= a }
            a <<= 1
            if a & 0x100 != 0 { a ^= 0x11D }
            b >>= 1
        }
        return UInt8(result)
    }

    /// Coefficients of the generator polynomial of `degree`, highest power first,
    /// without the leading 1.
    static func generator(degree: Int) -> [UInt8] {
        var coefficients = [UInt8](repeating: 0, count: degree)
        coefficients[degree - 1] = 1
        var root: UInt8 = 1
        for _ in 0..<degree {
            for index in 0..<degree {
                coefficients[index] = multiply(coefficients[index], root)
                if index + 1 < degree { coefficients[index] ^= coefficients[index + 1] }
            }
            root = multiply(root, 2)
        }
        return coefficients
    }

    /// The error correction codewords for `data`.
    static func remainder(of data: [UInt8], degree: Int) -> [UInt8] {
        let generator = generator(degree: degree)
        var result = [UInt8](repeating: 0, count: degree)
        for byte in data {
            let factor = byte ^ result.removeFirst()
            result.append(0)
            for index in 0..<degree { result[index] ^= multiply(generator[index], factor) }
        }
        return result
    }
}

// MARK: - Module grid

nonisolated private struct Grid {
    let size: Int
    private let version: Spec.Version
    var dark: [Bool]
    /// Finder, timing, alignment, format and version modules, which data and masks skip.
    private var reserved: [Bool]

    init(version: Spec.Version) {
        self.version = version
        size = version.size
        dark = Array(repeating: false, count: size * size)
        reserved = Array(repeating: false, count: size * size)
        drawFunctionPatterns()
    }

    private mutating func set(_ row: Int, _ column: Int, _ isDark: Bool) {
        dark[row * size + column] = isDark
        reserved[row * size + column] = true
    }

    private mutating func drawFunctionPatterns() {
        for index in 0..<size {
            set(6, index, index % 2 == 0)
            set(index, 6, index % 2 == 0)
        }
        drawFinder(centerRow: 3, centerColumn: 3)
        drawFinder(centerRow: 3, centerColumn: size - 4)
        drawFinder(centerRow: size - 4, centerColumn: 3)

        let centers = version.alignmentCenters
        for row in centers {
            for column in centers {
                let overlapsFinder = (row == 6 && column == 6)
                    || (row == 6 && column == centers.last)
                    || (row == centers.last && column == 6)
                if !overlapsFinder { drawAlignment(centerRow: row, centerColumn: column) }
            }
        }

        drawFormatBits(mask: 0)  // Reserves the area; overwritten after masking.
        if version.number >= 7 {
            let bits = QRCode.versionBits(version.number)
            for index in 0..<18 {
                let isDark = (bits >> index) & 1 == 1
                let a = size - 11 + index % 3
                let b = index / 3
                set(b, a, isDark)
                set(a, b, isDark)
            }
        }
    }

    private mutating func drawFinder(centerRow: Int, centerColumn: Int) {
        for dy in -4...4 {
            for dx in -4...4 {
                let row = centerRow + dy
                let column = centerColumn + dx
                guard (0..<size).contains(row), (0..<size).contains(column) else { continue }
                let distance = max(abs(dx), abs(dy))
                set(row, column, distance != 2 && distance != 4)
            }
        }
    }

    private mutating func drawAlignment(centerRow: Int, centerColumn: Int) {
        for dy in -2...2 {
            for dx in -2...2 {
                set(centerRow + dy, centerColumn + dx, max(abs(dx), abs(dy)) != 1)
            }
        }
    }

    mutating func drawFormatBits(mask: Int) {
        let bits = QRCode.formatBits(mask: mask)
        func bit(_ index: Int) -> Bool { (bits >> index) & 1 == 1 }

        for index in 0...5 { set(index, 8, bit(index)) }
        set(7, 8, bit(6))
        set(8, 8, bit(7))
        set(8, 7, bit(8))
        for index in 9..<15 { set(8, 14 - index, bit(index)) }

        for index in 0..<8 { set(8, size - 1 - index, bit(index)) }
        for index in 8..<15 { set(size - 15 + index, 8, bit(index)) }
        set(size - 8, 8, true)  // Always-dark module.
    }

    /// Places codewords in the two-column zigzag from the bottom right, skipping the
    /// vertical timing pattern.
    mutating func placeData(_ codewords: [UInt8]) {
        let totalBits = codewords.count * 8
        var bitIndex = 0
        var right = size - 1
        while right >= 1 {
            if right == 6 { right = 5 }
            let upward = (right + 1) & 2 == 0
            for step in 0..<size {
                let row = upward ? size - 1 - step : step
                for column in [right, right - 1] where !reserved[row * size + column] {
                    if bitIndex < totalBits {
                        let byte = codewords[bitIndex >> 3]
                        dark[row * size + column] = (byte >> (7 - (bitIndex & 7))) & 1 == 1
                        bitIndex += 1
                    }
                }
            }
            right -= 2
        }
    }

    mutating func applyMask(_ mask: Int) {
        for row in 0..<size {
            for column in 0..<size where !reserved[row * size + column] {
                let flip: Bool
                switch mask {
                case 0: flip = (row + column) % 2 == 0
                case 1: flip = row % 2 == 0
                case 2: flip = column % 3 == 0
                case 3: flip = (row + column) % 3 == 0
                case 4: flip = (row / 2 + column / 3) % 2 == 0
                case 5: flip = (row * column) % 2 + (row * column) % 3 == 0
                case 6: flip = ((row * column) % 2 + (row * column) % 3) % 2 == 0
                default: flip = ((row + column) % 2 + (row * column) % 3) % 2 == 0
                }
                if flip { dark[row * size + column].toggle() }
            }
        }
    }

    /// The specification's four penalty rules; the mask with the lowest score is used.
    func penalty() -> Int {
        func module(_ row: Int, _ column: Int) -> Bool { dark[row * size + column] }
        var score = 0

        for horizontal in [true, false] {
            for line in 0..<size {
                let values = (0..<size).map { horizontal ? module(line, $0) : module($0, line) }
                // Rule 1: runs of five or more modules of one color.
                var runLength = 1
                for index in 1...values.count {
                    if index < values.count && values[index] == values[index - 1] {
                        runLength += 1
                    } else {
                        if runLength >= 5 { score += 3 + runLength - 5 }
                        runLength = 1
                    }
                }
                // Rule 3: finder-like 1:1:3:1:1 patterns with four light modules on a side.
                let pattern: [Bool] = [true, false, true, true, true, false, true]
                let light = [Bool](repeating: false, count: 4)
                for start in 0...(values.count - 11) {
                    let window = Array(values[start..<start + 11])
                    if window == pattern + light || window == light + pattern { score += 40 }
                }
            }
        }

        // Rule 2: 2×2 blocks of one color.
        for row in 0..<size - 1 {
            for column in 0..<size - 1 {
                let color = module(row, column)
                if module(row, column + 1) == color && module(row + 1, column) == color
                    && module(row + 1, column + 1) == color {
                    score += 3
                }
            }
        }

        // Rule 4: deviation of the dark proportion from 50%, in steps of 5%.
        let darkCount = dark.filter { $0 }.count
        let deviation = abs(darkCount * 100 / dark.count - 50)
        score += deviation / 5 * 10
        return score
    }
}
