//
//  MongoCollection.swift
//  swiftMongoDB
//
//  Created by Dan Appel on 8/20/15.
//  Copyright © 2015 Dan Appel. All rights reserved.
//

#if os(Linux)
import mongocLinux
#else
import mongocMac
#endif

class MongoCollection {

    let name: String
    let databaseName: String

    let collectionRaw: _mongoc_collection

    convenience init(name: String, database: MongoDatabase) {

        let ptr = mongoc_database_get_collection(database.databaseRaw, name)
        self.init(name: name, databaseName: database.name, ptr: ptr)
    }

    init(name: String, databaseName: String, ptr: _mongoc_collection) {
        self.name = name
        self.databaseName = databaseName
        self.collectionRaw = ptr
    }


    deinit {
        mongoc_collection_destroy(self.collectionRaw)
    }

    func insert(document: MongoDocument, flags: InsertFlags = InsertFlags.None) throws {

        var document = try MongoBSON(data: document.data).bson

        var error = bson_error_t()

        mongoc_collection_insert(self.collectionRaw, flags.rawFlag, &document, nil, &error)

        try error.throwIfError()
    }

    func insert(document: DocumentData, flags: InsertFlags = InsertFlags.None) throws {

        try self.insert(MongoDocument(data: document), flags: flags)
    }

    func renameCollectionTo(newName : String) throws {
        var error = bson_error_t()
        mongoc_collection_rename(self.collectionRaw, databaseName, newName, false, &error)

        try error.throwIfError()
    }

    func find(query: DocumentData = .NullValue, 
        flags: QueryFlags = QueryFlags.None, skip: Int = 0, 
        limit: Int = 0, batchSize: Int = 0) throws -> [MongoDocument] {

            var query = try MongoBSON(data: query).bson

            // standard options - should be customizable later on
            let cursor = MongoCursor(
                collection: self,
                operation: .Find,
                query: &query,
                options: (
                    queryFlags: flags.rawFlag,
                    skip: skip,
                    limit: limit,
                    batchSize: batchSize
                )
            )

            let documents = try cursor.getDocuments()
    
            if cursor.lastError.isError {
                throw cursor.lastError
            }

            return documents
    }

    func findOne(query: DocumentData = .NullValue, flags: QueryFlags = QueryFlags.None, skip: Int = 0, batchSize: Int = 0) throws -> MongoDocument? {

        let doc = try find(query, flags: flags, skip: skip, limit: 1, batchSize: batchSize)

        if doc.count == 0 {
            return nil
        } else {
            return doc[0]
        }
    }

    func update(query: DocumentData = .NullValue, newValue: DocumentData, 
        flags: UpdateFlags = UpdateFlags.None) throws -> Bool {

            var query = try MongoBSON(data: query).bson

            var document = try MongoBSON(data: newValue).bson

            var error = bson_error_t()
            let success = mongoc_collection_update(self.collectionRaw, flags.rawFlag, &query, &document, nil, &error)
            try error.throwIfError()

            return success
    }


    func remove(query: DocumentData = .NullValue, 
        flags: RemoveFlags = RemoveFlags.None) throws -> Bool {

            var query = try MongoBSON(data: query).bson

            var error = bson_error_t()
            let success = mongoc_collection_remove(self.collectionRaw, 
                            flags.rawFlag, &query, nil, &error)

            try error.throwIfError()

            return success
    }

    func save(document: DocumentData) throws -> Bool {

        var document = try MongoBSON(data: document).bson
        var error = bson_error_t()

        let success = mongoc_collection_save(collectionRaw, &document, nil, &error)

        try error.throwIfError()

        return success
    }

    func performBasicCollectionCommand(command: DocumentData) throws -> DocumentData {

        var command = try MongoBSON(data: command).bson

        var reply = bson_t()
        var error = bson_error_t()

        mongoc_collection_command_simple(self.collectionRaw, &command, nil, &reply, &error)

        try error.throwIfError()

        return try MongoBSON(bson: reply).data
    }

    func destroy() {
        mongoc_collection_destroy(collectionRaw)
    }

    func performCommand(command: DocumentData, flags: QueryFlags, options: QueryOptions, fields: [String]) throws -> MongoCursor {

        var command = try MongoBSON(data: command).bson
        var fields = try MongoBSON(json: fields.toJSON()).bson

        let cursor = mongoc_collection_command(collectionRaw, flags.rawFlag, options.skip.UInt32Value, options.limit.UInt32Value, options.batchSize.UInt32Value, &command, &fields, nil)

        return MongoCursor(cursor: cursor)
    }

    func count(query: DocumentData, flags: QueryFlags, skip: Int, limit: Int) throws -> Int {

        var query = try MongoBSON(data: query).bson

        var error = bson_error_t()

        let count = mongoc_collection_count(collectionRaw, flags.rawFlag, &query, Int64(skip), Int64(limit), nil, &error)

        try error.throwIfError()

        return Int(count)
    }

    func drop() throws {

        var error = bson_error_t()

        mongoc_collection_drop(collectionRaw, &error)

        try error.throwIfError()
    }

    func rename(newDatabase: String, newCollection: String, dropBeforeRename: Bool) throws -> Bool {

        var error = bson_error_t()

        let success = mongoc_collection_rename(collectionRaw, newDatabase, newCollection, dropBeforeRename, &error)

        try error.throwIfError()

        return success
    }

    func stats(options: DocumentData) throws -> DocumentData {

        var options = try MongoBSON(data: options).bson

        var reply = bson_t()
        var error = bson_error_t()

        mongoc_collection_stats(collectionRaw, &options, &reply, &error)

        try error.throwIfError()

        return try MongoBSON(bson: reply).data
    }

    func validate(options: DocumentData) throws -> DocumentData {
        var options = try MongoBSON(data: options).bson

        var reply = bson_t()
        var error = bson_error_t()

        mongoc_collection_validate(collectionRaw, &options, &reply, &error)

        try error.throwIfError()

        return try MongoBSON(bson: reply).data
    }

    // TODO
    //func mongoc_collection_find_and_modify(collection: COpaquePointer, _ query: UnsafePointer<bson_t>, _ sort: UnsafePointer<bson_t>, _ update: UnsafePointer<bson_t>, _ fields: UnsafePointer<bson_t>, _ _remove: Bool, _ upsert: Bool, _ _new: Bool, _ reply: UnsafeMutablePointer<bson_t>, _ error: UnsafeMutablePointer<bson_error_t>) -> Bool
}
