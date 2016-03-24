import Foundation
import ReSwift
import SocketIOClientSwift

public typealias TypeMap = [String: StandardActionConvertible.Type]

public class RecordingMainStore<State: StateType>: Store<State> {

    var initialState: State!
    var actionHistory = [Action]()
    var actionCount = 0
    var socket: SocketIOClient!

    private var typeMap: TypeMap = [:]

    typealias RecordedActions = [[String : AnyObject]]
    var recordedActions: RecordedActions = []
    var computedStates: [State] = []
    let recordingPath: String?

    public init(reducer: AnyReducer, state: State?, typeMaps: [TypeMap], recording: String? = nil) {

        self.recordingPath = recording

        super.init(reducer: reducer, state: state, middleware: [])

        self.initialState = self.state
        self.computedStates.append(initialState)

        // merge all typemaps into one
        typeMaps.forEach { typeMap in
            for (key, value) in typeMap {
                self.typeMap[key] = value
            }
        }

        if let recording = recording {
            actionHistory = loadActions(recording)
            self.replayToState(actionHistory, state: actionHistory.count)
        }
    }

    public required init(reducer: AnyReducer, appState: StateType, middleware: [Middleware]) {
        fatalError("The current barebones implementation of ReSwiftRecorder does not support " +
            "middleware!")
    }

    public required convenience init(reducer: AnyReducer, appState: StateType) {
        fatalError("The current Barebones implementation of ReSwiftRecorder does not support " +
            "this initializer!")
    }

    func dispatchRecorded(action: Action) {
        super.dispatch(action)

        recordAction(action)
    }

    public override func dispatch(action: Action) -> Any {
        if let actionsToReplay = actionCount where actionsToReplay > 0 {
            // ignore actions that are dispatched during replay
            return action
        }

        super.dispatch(action)

        self.computedStates.append(self.state)

        if let standardAction = convertActionToStandardAction(action) {
            recordAction(standardAction)
            actionHistory.append(standardAction)
        }

        return action
    }

    func recordAction(action: Action) {
        let standardAction = convertActionToStandardAction(action)

        if let standardAction = standardAction {
            let recordedAction: [String : AnyObject] = [
                "timestamp": NSDate.timeIntervalSinceReferenceDate(),
                "action": standardAction.dictionaryRepresentation()
            ]

            recordedActions.append(recordedAction)
            storeActions(recordedActions)
        } else {
            print("ReSwiftRecorder Warning: Could not log following action because it does not " +
                "conform to StandardActionConvertible: \(action)")
        }
    }

    private func convertActionToStandardAction(action: Action) -> StandardAction? {

        if let standardAction = action as? StandardAction {
            return standardAction
        } else if let standardActionConvertible = action as? StandardActionConvertible {
            return standardActionConvertible.toStandardAction()
        }

        return nil
    }

    private func decodeAction(jsonDictionary: [String : AnyObject]) -> Action {
        let standardAction = StandardAction(dictionary: jsonDictionary)

        if !standardAction.isTypedAction {
            return standardAction
        } else {
            let typedActionType = self.typeMap[standardAction.type]!
            return typedActionType.init(standardAction)
        }
    }

    lazy var recordingDirectory: NSURL? = {
        let timestamp = Int(NSDate.timeIntervalSinceReferenceDate())

        let documentDirectoryURL = try? NSFileManager.defaultManager()
            .URLForDirectory(.DocumentDirectory, inDomain:
                .UserDomainMask, appropriateForURL: nil, create: true)

        let path = documentDirectoryURL?
            .URLByAppendingPathComponent("recording.json")

        print("Recording to path: \(path)")
        return path
    }()

    lazy var documentsDirectory: NSURL? = {
        let documentDirectoryURL = try? NSFileManager.defaultManager()
            .URLForDirectory(.DocumentDirectory, inDomain:
                .UserDomainMask, appropriateForURL: nil, create: true)

        return documentDirectoryURL
    }()

    private func storeActions(actions: RecordedActions) {
        guard let data = try? NSJSONSerialization.dataWithJSONObject(
            actions, options: .PrettyPrinted) else { return }

        if let path = recordingDirectory {
            data.writeToURL(path, atomically: true)
        }
    }

    private func loadActions(recording: String) -> [Action] {
        guard let recordingPath = documentsDirectory?.URLByAppendingPathComponent(recording) else {
            return []
        }
        guard let data = NSData(contentsOfURL: recordingPath) else { return [] }

        guard let jsonArray = try? NSJSONSerialization.JSONObjectWithData(
            data, options: NSJSONReadingOptions(rawValue: 0)) as? Array<AnyObject>
            else { return [] }

        let flatArray = jsonArray.flatMap { $0 as? [[String: AnyObject]] } ?? []

        return flatArray.flatMap { $0["action"] as? [String : AnyObject] }
            .map { decodeAction($0) }
    }

    private func replayToState(actions: [Action], state: Int) {
        if state > computedStates.count - 1 {
            print("Rewind to \(state)...")
            self.state = initialState
            recordedActions = []
            actionCount = state

            for i in 0..<state {
                dispatchRecorded(actions[i])
                self.actionCount = self.actionCount! - 1
                self.computedStates.append(self.state)
            }
        } else {
            self.state = computedStates[state]
        }
    }
}
