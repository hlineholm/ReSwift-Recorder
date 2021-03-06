//
//  StandardAction.swift
//  ReSwiftRecorder
//
//  Created by Malcolm Jarvis on 2017-06-28.
//  Copyright © 2017 Benjamin Encz. All rights reserved.
//

import Foundation
import ReSwift

/**
 It is recommended that you define your own types that conform to `Action` - if you want to be able
 to serialize your custom action types, you can implement `StandardActionConvertible` which will
 make it possible to generate a `StandardAction` from your typed action - the best of both worlds!
 */
public struct StandardAction: Action {
    /// A String that identifies the type of this `StandardAction`
    public let type: String
    /// An untyped, JSON-compatible payload
    public let payload: [String: AnyObject]?
    /// Indicates whether this action will be deserialized as a typed action or as a standard action
    public let isTypedAction: Bool

    /**
     Initializes this `StandardAction` with a type, a payload and information about whether this is
     a typed action or not.

     - parameter type:          String representation of the Action type
     - parameter payload:       Payload convertable to JSON
     - parameter isTypedAction: Is Action a subclassed type
     */
    public init(type: String, payload: [String: AnyObject]? = nil, isTypedAction: Bool = false) {
        self.type = type
        self.payload = payload
        self.isTypedAction = isTypedAction
    }
}

// MARK: Coding Extension

private let typeKey = "type"
private let payloadKey = "payload"
private let isTypedActionKey = "isTypedAction"
let reSwiftNull = "ReSwift_Null"

extension StandardAction: Coding {

    public init?(dictionary: [String: AnyObject]) {
        guard let type = dictionary[typeKey] as? String,
            let isTypedAction = dictionary[isTypedActionKey] as? Bool else { return nil }
        self.type = type
        self.payload = dictionary[payloadKey] as? [String: AnyObject]
        self.isTypedAction = isTypedAction
    }

    public var dictionaryRepresentation: [String: AnyObject] {
        let payload: AnyObject = self.payload as AnyObject? ?? reSwiftNull as AnyObject

        return [typeKey: type as NSString,
                payloadKey: payload,
                isTypedActionKey: isTypedAction as NSNumber]
    }
}

/// Implement this protocol on your custom `Action` type if you want to make the action
/// serializable.
/// - Note: We are working on a tool to automatically generate the implementation of this protocol
///     for your custom action types.
public protocol StandardActionConvertible: Action {
    /**
     Within this initializer you need to use the payload from the `StandardAction` to configure the
     state of your custom action type.

     Example:

     ```
     init(_ standardAction: StandardAction) {
     self.twitterUser = decode(standardAction.payload!["twitterUser"]!)
     }
     ```

     - Note: If you, as most developers, only use action serialization/deserialization during
     development, you can feel free to use the unsafe `!` operator.
     */
    init (_ standardAction: StandardAction)

    /**
     Use the information from your custom action to generate a `StandardAction`. The `type` of the
     StandardAction should typically match the type name of your custom action type. You also need
     to set `isTypedAction` to `true`. Use the information from your action's properties to
     configure the payload of the `StandardAction`.

     Example:

     ```
     func toStandardAction() -> StandardAction {
     let payload = ["twitterUser": encode(self.twitterUser)]

     return StandardAction(type: SearchTwitterScene.SetSelectedTwitterUser.type,
     payload: payload, isTypedAction: true)
     }
     ```

     */
    func toStandardAction() -> StandardAction
}
