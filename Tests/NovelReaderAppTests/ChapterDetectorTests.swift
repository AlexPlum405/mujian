import Testing
@testable import NovelReaderApp

struct ChapterDetectorTests {
    @Test func detectsChineseArabicNumberedChapters() {
        let chapters = ChapterDetector().detectChapters(in: """
        第1章 初遇
        正文一
        第 2 章 重逢
        正文二
        """)

        #expect(chapters.map(\.title) == ["第1章 初遇", "第 2 章 重逢"])
        #expect(chapters[0].body == "正文一")
        #expect(chapters[1].body == "正文二")
    }

    @Test func detectsChineseNumberedChaptersAndVolumes() {
        let chapters = ChapterDetector().detectChapters(in: """
        卷一 风起
        第一章 旧书店
        正文
        """)

        #expect(chapters.map(\.title) == ["卷一 风起", "第一章 旧书店"])
    }

    @Test func detectsStructureTitles() {
        let chapters = ChapterDetector().detectChapters(in: """
        楔子
        开场
        序章
        序章正文
        番外 · 雨夜
        番外正文
        """)

        #expect(chapters.map(\.title) == ["楔子", "序章", "番外 · 雨夜"])
    }

    @Test func detectsEnglishChaptersCaseInsensitively() {
        let chapters = ChapterDetector().detectChapters(in: """
        Chapter 1: The Light
        Body
        CHAPTER 2 - The Rain
        Body 2
        """)

        #expect(chapters.map(\.title) == ["Chapter 1: The Light", "CHAPTER 2 - The Rain"])
    }

    @Test func fallsBackToWholeTextWhenNoChapterIsDetected() {
        let text = "这是一段没有章节标题的正文。"

        let chapters = ChapterDetector().detectChapters(in: text)

        #expect(chapters == [.fallback(body: text)])
    }

    @Test func detectsChaptersWithCustomPattern() {
        let chapters = ChapterDetector().detectChapters(
            in: """
            第1话 开端
            正文一
            第2话 转折
            正文二
            """,
            customPattern: #"^第\d+话"#
        )

        #expect(chapters.count == 2)
        #expect(chapters.map(\.title) == ["第1话 开端", "第2话 转折"])
        #expect(chapters[0].body == "正文一")
        #expect(chapters[1].body == "正文二")
    }

    @Test func ignoresInvalidCustomPatternAndFallsBackToBuiltInRules() {
        let chapters = ChapterDetector().detectChapters(
            in: """
            第一章 开端
            正文一
            第二章 转折
            正文二
            """,
            customPattern: "["
        )

        #expect(chapters.count == 2)
        #expect(chapters.map(\.title) == ["第一章 开端", "第二章 转折"])
    }

    @Test func treatsNilCustomPatternIdenticallyToDefaultCall() {
        let text = """
        第一章 开端
        正文一
        第二章 转折
        正文二
        """

        let withNil = ChapterDetector().detectChapters(in: text, customPattern: nil)
        let withoutArgument = ChapterDetector().detectChapters(in: text)

        #expect(withNil == withoutArgument)
    }
}
