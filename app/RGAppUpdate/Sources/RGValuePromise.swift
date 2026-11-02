// MARK: LUIYo — minimal observable value holder.
//
// Replaces the external ValuePromise type this module previously
// depended on: the current value is readable synchronously and
// changes are published through Combine, which the updater
// already uses.
import Combine
import Foundation

public final class RGValuePromise<Value: Equatable> {
    public var value: Value { subject.value }
    public var publisher: AnyPublisher<Value, Never> { subject.eraseToAnyPublisher() }
    private let subject: CurrentValueSubject<Value, Never>
    private let ignoreRepeated: Bool

    public init(_ value: Value, ignoreRepeated: Bool = false) {
        self.subject = CurrentValueSubject(value)
        self.ignoreRepeated = ignoreRepeated
    }

    public func set(_ newValue: Value) {
        if ignoreRepeated && newValue == subject.value { return }
        subject.send(newValue)
    }
}
