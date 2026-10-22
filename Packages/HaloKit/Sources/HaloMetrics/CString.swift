#if os(macOS)
extension String {
    /// Decodes a fixed-size C buffer filled in by a system call, up to its terminating NUL.
    init(nulTerminated buffer: [CChar]) {
        self.init(decoding: buffer.prefix { $0 != 0 }.map { UInt8(bitPattern: $0) }, as: UTF8.self)
    }
}
#endif
