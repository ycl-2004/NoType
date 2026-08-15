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
        // Sounds with no lexical meaning are always safe to drop.
        let disfluencyPattern = #"(?i)(?<=^|[\s,，。.!?])(?:um|uh|erm|ah)(?=$|[\s,，。.!?])"#

        // "like", "you know" and "i mean" are ordinary words first and fillers second: dropping
        // them on sight turns "I like it" into "I it". Only a pause on both sides marks them as
        // filler, so everything else is left alone — keeping a stray filler costs far less than
        // deleting a real word.
        let pausedFillerPattern = #"(?i)[,，]\s*(?:like|you know|i mean)\s*(?=[,，])"#

        // Trailing "you know" / "i mean" have no object left to attach to, so they read as filler.
        // "like" is deliberately excluded here — "what's it like" ends a perfectly ordinary
        // sentence.
        let trailingFillerPattern = #"(?i)[\s,，]+(?:you know|i mean)[\s.,!?。，！？]*$"#

        return text
            .replacingOccurrences(of: disfluencyPattern, with: " ", options: .regularExpression)
            .replacingOccurrences(of: pausedFillerPattern, with: "", options: .regularExpression)
            .replacingOccurrences(of: trailingFillerPattern, with: "", options: .regularExpression)
    }

    private static func collapseWhitespace(in text: String) -> String {
        text.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
    }

    /// Whisper was trained on a lot of subtitled video, so when an utterance ends in silence it
    /// tends to append the sign-off such videos end with — words the speaker never said. These are
    /// only stripped from the very end, so quoting one mid-sentence keeps it intact.
    private static func removeTrailingHallucinatedClosers(from text: String) -> String {
        let patterns = [
            #"(?i)([\s,，。.!?！？；;:：、]+)(thank you|thanks)([\s.!?。！？]*)$"#,
            // Chinese runs without spaces, so the sign-off attaches straight to the last real word
            // and the leading separator has to be optional.
            #"[\s,，。.!?！？；;:：、]*(?:謝謝|谢谢)(?:大家|大傢|觀看|观看|收看|您的觀看|您的观看|聆聽|聆听)?[\s.!?。！？]*$"#,
            #"[\s,，。.!?！？；;:：、]*請不吝[點点]贊[\s、,，]*訂閱[^。！？]*$"#,
            #"[\s,，。.!?！？；;:：、]*请不吝[点點]赞[\s、,，]*订阅[^。！？]*$"#,
            #"[\s,，。.!?！？；;:：、]*字幕(?:由|志願者|志愿者)[^。！？]*$"#
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
