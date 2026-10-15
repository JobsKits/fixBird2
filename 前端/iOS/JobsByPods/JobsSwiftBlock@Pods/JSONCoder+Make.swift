//
//  JSONCoder+Make.swift
//  JobsSwiftBlock
//
//  Created by Jobs on 2026年8月7日，星期五.
//

import Foundation

public extension JSONDecoder {

    static func make(_ configure: (JSONDecoder) -> Void) -> JSONDecoder {
        let decoder = JSONDecoder()
        configure(decoder)
        return decoder
    }
}

public extension JSONEncoder {

    static func make(_ configure: (JSONEncoder) -> Void) -> JSONEncoder {
        let encoder = JSONEncoder()
        configure(encoder)
        return encoder
    }
}
