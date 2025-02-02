//  MongoBSON.swift
//  swiftMongoDB
//
//  Created by Dan Appel on 8/20/15.
//  Copyright © 2015 Dan Appel. All rights reserved.
//

#if os(Linux)
import bsonLinux
#else
import bsonMac
#endif

import PureJsonSerializer

class MongoBSON {

    private var _bson: bson_t
    let json: String
    let data: Json
    var bson: bson_t {
        return bson_copy(&_bson).memory // for safety
    }

    init(bson: bson_t) throws {

        self._bson = bson

        do {
            self.json = try MongoBSON.bsonToJson(bson)
        } catch {
            self.json = ""
            self.data = [:]
            throw error
        }

        do {
            self.data = try json.parseJSON()
        } catch {
            self.data = [:]
            throw error
        }
    }

    init(json: String) throws {

        self.json = json

        do {
            self.data = try self.json.parseJSON()
        } catch {
            self.data = [:]
            self._bson = bson_t()
            throw error
        }

        do {
            self._bson = try MongoBSON.jsonToBson(json)
        } catch {
            self._bson = bson_t()
            throw error
        }
    }

    init(data: DocumentData) throws {

        self.data = data

        self.json = data.serialize()

        do {
            self._bson = try MongoBSON.jsonToBson(json)
        } catch {
            self._bson = bson_t()
            throw error
        }
    }

    static func bsonToJson(bson: bson_t) throws -> String {

        var bson = bson
        let jsonRaw = bson_as_json(&bson, nil)

        if jsonRaw == nil {
            throw MongoError.CorruptDocument
        }

        return String(UTF8String: jsonRaw)!
    }

    static func jsonToBson(json: String) throws -> bson_t {

        var error = bson_error_t()
        let bson = bson_new_from_json(json, json.nulTerminatedUTF8.count, &error)

        try error.throwIfError()

        return bson.memory
    }

    func copyTo(out: _bson_ptr_mutable) {
        var bson = self.bson
        bson_copy_to(&bson, out)
    }
}
