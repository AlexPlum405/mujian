import Foundation

enum EncodingDetector {
    static func detect(data: Data, httpCharset: String? = nil) -> String.Encoding {
        if let httpCharset, let encoding = encoding(from: httpCharset) {
            return encoding
        }

        if let head = String(data: data.prefix(2048), encoding: .ascii) {
            let lower = head.lowercased()

            if let metaRange = lower.range(of: "charset=") {
                let after = String(lower[metaRange.upperBound...])
                var charsetName = ""
                for char in after {
                    if char == "\"" || char == "'" || char == ">" || char == " " || char == "/" {
                        break
                    }
                    charsetName.append(char)
                }

                if let encoding = encoding(from: charsetName) {
                    return encoding
                }
            }

            if lower.contains("gb2312") || lower.contains("gbk") || lower.contains("gb18030") {
                return encoding(from: "gb18030") ?? .utf8
            }

            if lower.contains("big5") {
                return encoding(from: "big5") ?? .utf8
            }

            if lower.contains("shift_jis") || lower.contains("shift-jis") || lower.contains("sjis") {
                return encoding(from: "shift_jis") ?? .utf8
            }
        }

        if let _ = String(data: data, encoding: .utf8) {
            return .utf8
        }

        return .utf8
    }

    static func encoding(from name: String) -> String.Encoding? {
        let lower = name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        switch lower {
        case "utf-8", "utf8":
            return .utf8
        case "gb2312", "gbk", "gb18030":
            let cfEncoding = CFStringEncoding(CFStringEncodings.GB_18030_2000.rawValue)
            let nsEncoding = CFStringConvertEncodingToNSStringEncoding(cfEncoding)
            return nsEncoding != kCFStringEncodingInvalidId ? String.Encoding(rawValue: nsEncoding) : nil
        case "big5":
            let cfEncoding = CFStringEncoding(CFStringEncodings.big5.rawValue)
            let nsEncoding = CFStringConvertEncodingToNSStringEncoding(cfEncoding)
            return nsEncoding != kCFStringEncodingInvalidId ? String.Encoding(rawValue: nsEncoding) : nil
        case "shift_jis", "shift-jis", "sjis", "windows-31j":
            let cfEncoding = CFStringEncoding(CFStringEncodings.shiftJIS.rawValue)
            let nsEncoding = CFStringConvertEncodingToNSStringEncoding(cfEncoding)
            return nsEncoding != kCFStringEncodingInvalidId ? String.Encoding(rawValue: nsEncoding) : nil
        case "euc-jp":
            let cfEncoding = CFStringEncoding(CFStringEncodings.EUC_JP.rawValue)
            let nsEncoding = CFStringConvertEncodingToNSStringEncoding(cfEncoding)
            return nsEncoding != kCFStringEncodingInvalidId ? String.Encoding(rawValue: nsEncoding) : nil
        case "euc-kr":
            let cfEncoding = CFStringEncoding(CFStringEncodings.EUC_KR.rawValue)
            let nsEncoding = CFStringConvertEncodingToNSStringEncoding(cfEncoding)
            return nsEncoding != kCFStringEncodingInvalidId ? String.Encoding(rawValue: nsEncoding) : nil
        case "iso-8859-1", "latin1":
            return .isoLatin1
        case "windows-1252":
            let cfEncoding = CFStringEncoding(CFStringEncodings.dosLatin1.rawValue)
            let nsEncoding = CFStringConvertEncodingToNSStringEncoding(cfEncoding)
            return nsEncoding != kCFStringEncodingInvalidId ? String.Encoding(rawValue: nsEncoding) : nil
        default:
            let cfEncoding = CFStringConvertIANACharSetNameToEncoding(name as CFString)
            if cfEncoding != kCFStringEncodingInvalidId {
                let nsEncoding = CFStringConvertEncodingToNSStringEncoding(cfEncoding)
                if nsEncoding != kCFStringEncodingInvalidId {
                    return String.Encoding(rawValue: nsEncoding)
                }
            }
            return nil
        }
    }

    static func decode(data: Data, httpCharset: String? = nil) -> String {
        let encoding = detect(data: data, httpCharset: httpCharset)
        if let text = String(data: data, encoding: encoding) {
            return text
        }
        if let text = String(data: data, encoding: .utf8) {
            return text
        }
        return String(decoding: data, as: UTF8.self)
    }
}
