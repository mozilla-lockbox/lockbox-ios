/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

import Foundation

protocol ItemParser {
    func itemFromDictionary(_ dictionary: [String: Any]) throws -> Item
    func jsonStringFromItem(_ item: Item) throws -> String
}

enum ParserError: Error {
    case InvalidDictionary, InvalidItem
}

class Parser: NSObject, ItemParser {
    private let encoder: JSONEncoder

    private var itemProperties: [String] {
        return Mirror(reflecting: Item.Builder().build()).children.flatMap {
            $0.label
        }
    }

    init(encoder: JSONEncoder? = JSONEncoder()) {
        self.encoder = encoder!
        super.init()
    }

    func itemFromDictionary(_ dictionary: [String: Any]) throws -> Item {
        let sanitizedDictionary = dictionary.filter { pair -> Bool in
            return self.itemProperties.contains(pair.key)
        }

        var item: Item
        do {
            let json = try JSONSerialization.data(withJSONObject: sanitizedDictionary, options: [])

            item = try JSONDecoder().decode(Item.self, from: json)
        } catch {
            throw ParserError.InvalidDictionary
        }

        return item
    }

    func jsonStringFromItem(_ item: Item) throws -> String {
        var jsonString = ""

        do {
            let jsonData = try self.encoder.encode(item)
            jsonString = String(data: jsonData, encoding: .utf8)!
        } catch {
            throw ParserError.InvalidItem
        }

        return jsonString
    }
}
