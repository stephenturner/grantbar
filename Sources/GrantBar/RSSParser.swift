import Foundation

// @unchecked Sendable is safe here: RSSParser instances are created fresh per-fetch
// and never shared across concurrent tasks.
final class RSSParser: NSObject, XMLParserDelegate, @unchecked Sendable {

    struct ParsedFeed: Sendable {
        var title: String = ""
        var items: [ParsedItem] = []
    }

    struct ParsedItem: Sendable {
        var title: String = ""
        var link: String = ""
        var description: String = ""
        var guid: String = ""
        var pubDate: String = ""
    }

    private var result = ParsedFeed()
    private var currentItem: ParsedItem?
    private var currentText = ""
    private var feedTitleSet = false

    func parse(data: Data) -> ParsedFeed {
        result = ParsedFeed()
        currentItem = nil
        currentText = ""
        feedTitleSet = false

        let parser = XMLParser(data: data)
        parser.delegate = self
        parser.parse()
        return result
    }

    // MARK: - XMLParserDelegate

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName: String?,
        attributes: [String: String] = [:]
    ) {
        currentText = ""

        if elementName == "item" || elementName == "entry" {
            currentItem = ParsedItem()
        }

        // Atom feeds use <link href="..."/> with no text content
        if elementName == "link", currentItem != nil, let href = attributes["href"] {
            currentItem?.link = href
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        currentText += string
    }

    func parser(_ parser: XMLParser, foundCDATA CDATABlock: Data) {
        if let text = String(data: CDATABlock, encoding: .utf8) {
            currentText += text
        }
    }

    func parser(
        _ parser: XMLParser,
        didEndElement elementName: String,
        namespaceURI: String?,
        qualifiedName: String?
    ) {
        let text = currentText.trimmingCharacters(in: .whitespacesAndNewlines)

        if currentItem != nil {
            switch elementName {
            case "title":
                currentItem?.title = text
            case "link":
                // Only set from text content if not already set by href attribute
                if currentItem?.link.isEmpty ?? true {
                    currentItem?.link = text
                }
            case "description", "summary", "content:encoded":
                if currentItem?.description.isEmpty ?? true {
                    currentItem?.description = stripHTML(text)
                }
            case "guid", "id":
                currentItem?.guid = text
            case "pubDate", "published", "dc:date", "updated":
                if currentItem?.pubDate.isEmpty ?? true {
                    currentItem?.pubDate = text
                }
            case "item", "entry":
                if let item = currentItem {
                    result.items.append(item)
                }
                currentItem = nil
            default:
                break
            }
        } else if elementName == "title" && !feedTitleSet && !text.isEmpty {
            result.title = text
            feedTitleSet = true
        }

        currentText = ""
    }

    // MARK: - Helpers

    private func stripHTML(_ input: String) -> String {
        guard input.contains("<") else { return input }
        var result = ""
        var inTag = false
        for char in input {
            if char == "<" { inTag = true }
            else if char == ">" { inTag = false }
            else if !inTag { result.append(char) }
        }
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - Date parsing

struct RSSDateParser {
    private let formatter = DateFormatter()

    func parse(_ string: String) -> Date? {
        guard !string.isEmpty else { return nil }
        formatter.locale = Locale(identifier: "en_US_POSIX")
        let formats = [
            "EEE, dd MMM yyyy HH:mm:ss Z",
            "EEE, dd MMM yyyy HH:mm:ss zzz",
            "yyyy-MM-dd'T'HH:mm:ssZ",
            "yyyy-MM-dd'T'HH:mm:ss.SSSZ",
            "yyyy-MM-dd'T'HH:mm:ssXXXXX",
            "yyyy-MM-dd"
        ]
        for format in formats {
            formatter.dateFormat = format
            if let date = formatter.date(from: string) { return date }
        }
        return nil
    }
}
