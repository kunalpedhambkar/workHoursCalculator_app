import Foundation
import EventKit

protocol CalendarRepository {
    func requestAccess() async throws
    func calendars() -> [EKCalendar]
    func events(in calendar: EKCalendar, interval: DateInterval) -> [EKEvent]
}

final class EventKitService: CalendarRepository {
    private let store = EKEventStore()

    func requestAccess() async throws {
        if #available(iOS 17, *) {
            try await store.requestFullAccessToEvents()
        } else {
            try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
                store.requestAccess(to: .event) { granted, error in
                    if let error = error {
                        cont.resume(throwing: error)
                    } else if !granted {
                        cont.resume(throwing: NSError(
                            domain: "EventKit", code: 1,
                            userInfo: [NSLocalizedDescriptionKey: "Calendar access denied."]))
                    } else {
                        cont.resume(returning: ())
                    }
                }
            }
        }
    }

    func calendars() -> [EKCalendar] {
        store.calendars(for: .event).sorted {
            $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
        }
    }

    func events(in calendar: EKCalendar, interval: DateInterval) -> [EKEvent] {
        let predicate = store.predicateForEvents(
            withStart: interval.start,
            end: interval.end,
            calendars: [calendar]
        )
        return store.events(matching: predicate)
    }
}
