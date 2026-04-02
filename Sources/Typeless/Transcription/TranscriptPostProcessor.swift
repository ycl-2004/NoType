import Foundation

enum TranscriptPostProcessor {
    static func clean(
        _ text: String,
        preferredLanguage: DictationRecognitionLanguage,
        chineseScriptPreference: ChineseScriptPreference = .followModel
    ) -> String {
        let original = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard original.isEmpty == false else {
            return ""
        }

        var cleaned = original
        cleaned = removeChineseFillers(from: cleaned, preferredLanguage: preferredLanguage)
        cleaned = removeEnglishFillers(from: cleaned, preferredLanguage: preferredLanguage)
        cleaned = removeTrailingHallucinatedClosers(from: cleaned)
        cleaned = collapseWhitespace(in: cleaned)
        cleaned = normalizeChineseSpacing(in: cleaned)
        cleaned = normalizeChineseScript(in: cleaned, preference: chineseScriptPreference)
        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func removeChineseFillers(
        from text: String,
        preferredLanguage _: DictationRecognitionLanguage
    ) -> String {
        let patterns = [
            #"(?<=^|[\s,，。.!?])(?:嗯|呃|额|啊)(?=$|[\s,，。.!?])"#,
            #"(?<=^|[\s,，。.!?])(?:就是|然后|那个)(?=[\s,，。.!?])"#
        ]

        return patterns.reduce(text) { partialResult, pattern in
            partialResult.replacingOccurrences(
                of: pattern,
                with: " ",
                options: .regularExpression
            )
        }
    }

    private static func removeEnglishFillers(
        from text: String,
        preferredLanguage _: DictationRecognitionLanguage
    ) -> String {
        let patterns = [
            #"(?i)(?<=^|[\s,，。.!?])(?:um|uh|erm|ah)(?=$|[\s,，。.!?])"#,
            #"(?i)(?<=^|[\s,，。.!?])(?:you know|i mean)(?=$|[\s,，。.!?])"#,
            #"(?i)(?<=^|[\s,，。.!?])like(?=$|[\s,，。.!?])"#
        ]

        return patterns.reduce(text) { partialResult, pattern in
            partialResult.replacingOccurrences(
                of: pattern,
                with: " ",
                options: .regularExpression
            )
        }
    }

    private static func collapseWhitespace(in text: String) -> String {
        text.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
    }

    private static func removeTrailingHallucinatedClosers(from text: String) -> String {
        let patterns = [
            #"(?i)([\s,，。.!?！？；;:：、]+)(thank you|thanks)([\s.!?。！？]*)$"#,
            #"([\s,，。.!?！？；;:：、]+)(謝謝|谢谢)([\s.!?。！？]*)$"#
        ]

        return patterns.reduce(text) { partialResult, pattern in
            let trimmed = partialResult.trimmingCharacters(in: .whitespacesAndNewlines)
            guard let range = trimmed.range(of: pattern, options: .regularExpression) else {
                return partialResult
            }

            let prefix = trimmed[..<range.lowerBound].trimmingCharacters(in: .whitespacesAndNewlines)
            guard prefix.isEmpty == false else {
                return partialResult
            }

            return String(prefix)
        }
    }

    private static func normalizeChineseScript(
        in text: String,
        preference: ChineseScriptPreference
    ) -> String {
        switch preference {
        case .followModel:
            return text
        case .simplified:
            return text.applyingTransform(StringTransform("Traditional-Simplified"), reverse: false) ?? text
        case .traditional:
            return text.applyingTransform(StringTransform("Simplified-Traditional"), reverse: false) ?? text
        }
    }

    private static func normalizeChineseSpacing(in text: String) -> String {
        var normalized = text
        let noSpaceAround = ["，", "。", "！", "？", "：", "；", "、", ",", ".", "!", "?", ":", ";"]
        for token in noSpaceAround {
            normalized = normalized.replacingOccurrences(of: " \(token)", with: token)
            normalized = normalized.replacingOccurrences(of: "\(token) ", with: "\(token) ")
        }

        normalized = normalized.replacingOccurrences(of: #"\s+([，。！？：；、,.!?:;])"#, with: "$1", options: .regularExpression)
        normalized = normalized.replacingOccurrences(of: #"([（\(\[]) "#, with: "$1", options: .regularExpression)
        normalized = normalized.replacingOccurrences(of: #" ([）\)\]])"#, with: "$1", options: .regularExpression)
        return normalized
    }
}
