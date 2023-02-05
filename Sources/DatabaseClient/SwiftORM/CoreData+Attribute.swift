//  CoreData+Attribute.swift
//  Anime Now!
//
//  Created by ErrorErrorError on 11/16/22.
//  
//  Modified version of https://github.com/prisma-ai/Sworm

import CoreData
import Foundation
import OrderedCollections

enum AttributeError: Swift.Error {
    case failedToDecode(for: String, model: String)
    case failedToEncode(for: String, model: String)
    case failedToEncodeRelation(for: String, model: String)
    case badInput(Any?)
}

public final class Attribute<PlainObject: ManagedObjectConvertible>: Hashable {

    // MARK: Primitive Values

    public init<Value: ConvertableValue>(
        _ keyPath: WritableKeyPath<PlainObject, Value>,
        _ name: String
    ) {
        self.name = name
        self.encode = { plainObject, managedObject in
            managedObject[primitiveValue: name] = plainObject[keyPath: keyPath].encode()
        }
        self.decode = { plainObject, managedObject in
            do {
                plainObject[keyPath: keyPath] = try Value.decode(managedObject[primitiveValue: name])
            } catch {
                throw AttributeError.failedToDecode(for: name, model: PlainObject.entityName)
            }
        }
        self.keyPath = keyPath
    }

    // MARK: Optional Primitive Attribute

    public init<Value: ConvertableValue>(
        _ keyPath: WritableKeyPath<PlainObject, Value?>,
        _ name: String
    ) {
        self.name = name
        self.encode = { plainObject, managedObject in
            managedObject[primitiveValue: name] = plainObject[keyPath: keyPath]?.encode()
        }
        self.decode = { plainObject, managedObject in
            do {
                plainObject[keyPath: keyPath] = try Value?.decode(managedObject[primitiveValue: name])
            } catch {
                throw AttributeError.failedToDecode(for: name, model: PlainObject.entityName)
            }
        }
        self.keyPath = keyPath
    }

    // MARK: To One

    public init<Relation: ManagedObjectConvertible>(
        _ keyPath: WritableKeyPath<PlainObject, Relation>,
        _ name: String
    ) {
        self.name = name
        self.encode = { plainObject, managedObject in
            try plainObject[keyPath: keyPath].encodeAttributes(to: managedObject)
        }
        self.decode = { plainObject, managedObject in
            guard let object = managedObject.value(forKey: name) as? NSManagedObject else {
                throw AttributeError.failedToDecode(for: name, model: PlainObject.entityName)
            }

            plainObject[keyPath: keyPath] = try Relation(from: object)
        }
        self.keyPath = keyPath
        self.isRelation = true
    }

    // MARK: To Many

    public init<Relation: ManagedObjectConvertible>(
        _ keyPath: WritableKeyPath<PlainObject, Set<Relation>>,
        _ name: String
    ) {
        self.name = name
        self.encode = { plainObject, managedObject in
            let managedObjects = managedObject.mutableSetValue(forKey: name)
            let objects = plainObject[keyPath: keyPath]

            // Adding and updating existing elements
            for object in objects {
                var managed: NSManagedObject? = try managedObjects.first {
                    (try Relation(from: $0 as! NSManagedObject))[keyPath: Relation.idKeyPath] == object[keyPath: Relation.idKeyPath]
                } as? NSManagedObject

                if managed == nil {
                    managed = try managedObject.managedObjectContext?.fetchOne(Relation.all.where(Relation.idKeyPath == object[keyPath: Relation.idKeyPath]))
                }

                if managed == nil {
                    managed = managedObject.managedObjectContext?.insert(entity: Relation.entityName)
                }

                guard let managed else {
                    throw AttributeError.failedToEncodeRelation(for: name, model: PlainObject.entityName)
                }

                managedObjects.add(managed)
                try managed.update(object)
            }

            // Remove elements not in array
            let copiedManagedObjects = managedObjects.copy() as! NSSet

            for managed in copiedManagedObjects {
                guard let wrapped = try? Relation(from: managed as! NSManagedObject) else {
                    continue
                }

                if !objects.contains(where: { wrapped[keyPath: Relation.idKeyPath] == $0[keyPath: Relation.idKeyPath] }) {
                    managedObjects.remove(managed)
                }
            }
        }
        self.decode = { plainObject, managedObject in
            guard let objects = managedObject.value(forKey: name) as? NSSet as? Set<NSManagedObject> else {
                throw AttributeError.failedToDecode(for: name, model: PlainObject.entityName)
            }

            plainObject[keyPath: keyPath] = try Set(objects.compactMap { try Relation(from: $0) })
        }
        self.keyPath = keyPath
        self.isRelation = true
    }

    // MARK: To Many Ordered

    public init<Relation: ManagedObjectConvertible>(
        _ keyPath: WritableKeyPath<PlainObject, OrderedSet<Relation>>,
        _ name: String
    ) {
        self.name = name
        self.encode = { plainObject, managedObject in
            let managedObjects = managedObject.mutableOrderedSetValue(forKey: name)
            let objects = plainObject[keyPath: keyPath]

            // Adding and updating existing elements
            for (index, object) in objects.enumerated() {
                var managed: NSManagedObject? = try managedObjects.first {
                    (try Relation(from: $0 as! NSManagedObject))[keyPath: Relation.idKeyPath] == object[keyPath: Relation.idKeyPath]
                } as? NSManagedObject

                if managed == nil {
                    managed = try managedObject.managedObjectContext?.fetchOne(Relation.all.where(Relation.idKeyPath == object[keyPath: Relation.idKeyPath]))
                }

                if managed == nil {
                    managed = managedObject.managedObjectContext?.insert(entity: Relation.entityName)
                }

                guard let managed else {
                    throw AttributeError.failedToEncodeRelation(for: name, model: PlainObject.entityName)
                }

                if managedObjects.contains(managed) {
                    managedObjects.remove(managed)
                }

                managedObjects.insert(managed, at: index)

                try managed.update(object)
            }

            // Remove elements not in array
            let copiedManagedObjects = managedObjects.copy() as! NSOrderedSet

            for managed in copiedManagedObjects {
                guard let wrapped = try? Relation(from: managed as! NSManagedObject) else {
                    continue
                }

                if !objects.contains(where: { wrapped[keyPath: Relation.idKeyPath] == $0[keyPath: Relation.idKeyPath] }) {
                    managedObjects.remove(managed)
                }
            }
        }
        self.decode = { plainObject, managedObject in
            guard let objects = managedObject.value(forKey: name) as? NSOrderedSet else {
                throw AttributeError.failedToDecode(for: name, model: PlainObject.entityName)
            }

            plainObject[keyPath: keyPath] = try OrderedSet(objects.compactMap({ $0 as? NSManagedObject }).compactMap { try Relation(from: $0 ) })
        }
        self.keyPath = keyPath
        self.isRelation = true
    }

    public static func == (lhs: Attribute<PlainObject>, rhs: Attribute<PlainObject>) -> Bool {
        lhs.name == rhs.name
    }

    public func hash(into hasher: inout Hasher) {
        self.name.hash(into: &hasher)
    }

    let name: String
    let encode: (PlainObject, NSManagedObject) throws -> Void
    let decode: (inout PlainObject, NSManagedObject) throws -> Void
    let keyPath: PartialKeyPath<PlainObject>
    private(set) var isRelation: Bool = false
}

extension ManagedObjectConvertible {
    static func attribute<Value>(_ keyPath: KeyPath<Self, Value>) -> Attribute<Self> {
        self.attributes.first(where: { $0.keyPath == keyPath }).unsafelyUnwrapped
    }

    @discardableResult
    func encodeAttributes(to managedObject: NSManagedObject) throws -> NSManagedObject {
        try Self.attributes.forEach {
            try $0.encode(self, managedObject)
        }
        return managedObject
    }

    public init(from managedObject: NSManagedObject) throws {
        self.init()
        try Self.attributes.forEach {
            try $0.decode(&self, managedObject)
        }
    }
}

public protocol PrimitiveType {}

public protocol ConvertableValue {
    associatedtype ValueType: PrimitiveType
    func encode() -> ValueType
    static func decode(value: ValueType) throws -> Self
}

public extension ConvertableValue where Self: PrimitiveType {
    func encode() -> Self { self }
    static func decode(value: Self) throws -> Self { value }
}

extension ConvertableValue {
    static func decode(_ some: Any?) throws -> Self {
        guard let value = some as? Self.ValueType else {
            throw AttributeError.badInput(some)
        }
        return try Self.decode(value: value)
    }
}

extension Optional where Wrapped: ConvertableValue {
    static func decode(_ anyValue: Any?) throws -> Wrapped? {
        try anyValue.flatMap {
            try Wrapped.decode($0)
        }
    }
}

public extension RawRepresentable where RawValue: ConvertableValue {
    func encode() -> RawValue.ValueType {
        self.rawValue.encode()
    }

    static func decode(value: RawValue.ValueType) throws -> Self {
        let rawValue = try RawValue.decode(value: value)
        guard let value = Self(rawValue: rawValue) else {
            throw AttributeError.badInput(rawValue)
        }
        return value
    }
}

extension Int: PrimitiveType, ConvertableValue {}
extension Int16: PrimitiveType, ConvertableValue {}
extension Int32: PrimitiveType, ConvertableValue {}
extension Int64: PrimitiveType, ConvertableValue {}

extension Float: PrimitiveType, ConvertableValue {}
extension Double: PrimitiveType, ConvertableValue {}
extension Decimal: PrimitiveType, ConvertableValue {}

extension Bool: PrimitiveType, ConvertableValue {}
extension Date: PrimitiveType, ConvertableValue {}
extension String: PrimitiveType, ConvertableValue {}
extension Data: PrimitiveType, ConvertableValue {}
extension UUID: PrimitiveType, ConvertableValue {}
extension URL: PrimitiveType, ConvertableValue {}
