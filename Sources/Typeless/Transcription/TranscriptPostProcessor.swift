import Foundation

enum TranscriptPostProcessor {
    static func clean(_ text: String, preferredLanguage: DictationRecognitionLanguage) -> String {
        let original = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard original.isEmpty == false else {
            return ""
        }

        var cleaned = original
        cleaned = removeChineseFillers(from: cleaned, preferredLanguage: preferredLanguage)
        cleaned = removeEnglishFillers(from: cleaned, preferredLanguage: preferredLanguage)
        cleaned = collapseWhitespace(in: cleaned)
        cleaned = normalizeChineseSpacing(in: cleaned)
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
