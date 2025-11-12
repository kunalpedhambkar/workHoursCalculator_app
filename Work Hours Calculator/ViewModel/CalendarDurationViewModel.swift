import Foundation
import SwiftUI
import Combine
import EventKit

@MainActor
final class CalendarDurationViewModel: ObservableObject {
    
    // MARK: - Modes
    
    enum DedupStrategy: String, CaseIterable, Identifiable {
        case byTitle = "By Title (group by name)"
        var id: String { rawValue }
    }
    
    // MARK: - Group Model
    
    struct EventTitleGroup: Identifiable {
        let id: String              // normalized title
        let displayTitle: String    // readable title
        let count: Int              // number of instances with this title
        let totalSeconds: TimeInterval
    }
    
    // MARK: - Helpers (private)
    
    private func normalizeTitle(_ title: String?) -> String {
        let trimmed = (title ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "(untitled)" : trimmed.lowercased()
    }
    
    private func buildTitleGroups(from events: [EKEvent]) -> [EventTitleGroup] {
        let grouped = Dictionary(grouping: events, by: { normalizeTitle($0.title) })
        let groups: [EventTitleGroup] = grouped.map { (normTitle, items) in
            // pick a nice display title
            let display: String = {
                if let t = items.first?.title?.trimmingCharacters(in: .whitespacesAndNewlines), !t.isEmpty {
                    return t
                } else {
                    return normTitle == "(untitled)" ? "(untitled)" : normTitle.capitalized
                }
            }()
            
            // Special rule + DEBUG logs for "MarryBrown Dandenong (PC)"
            let specialNorm = normalizeTitle("MarryBrown Dandenong (PC)")
            let fiveHours: TimeInterval = 5 * 3600
            
            var rawTotal: TimeInterval = 0
            var adjustedTotal: TimeInterval = 0
            
            #if DEBUG
            var didLogHeader = false
            var df: DateFormatter?
            #endif
            
            for (idx, e) in items.enumerated() {
                let dur = max(0, e.endDate.timeIntervalSince(e.startDate))
                rawTotal += dur
                
                if normTitle == specialNorm {
                    #if DEBUG
                    if !didLogHeader {
                        df = DateFormatter()
                        df?.dateStyle = .short
                        df?.timeStyle = .short
                        print("[MB DEBUG] ---- MarryBrown Dandenong (PC) events (\(items.count)) ----")
                        didLogHeader = true
                    }
                    let startStr = df!.string(from: e.startDate)
                    let endStr = df!.string(from: e.endDate)
                    #endif
                    
                    if dur >= fiveHours {
                        let adj = max(0, dur - 1800) // deduct 0.5h from this instance
                        adjustedTotal += adj
                        #if DEBUG
                        print(String(format: "[MB DEBUG] #%02d  %@ -> %@   %.2f h  |  deduction -0.50 h -> %.2f h",
                                     idx + 1, startStr, endStr, dur/3600.0, adj/3600.0))
                        #endif
                    } else {
                        adjustedTotal += dur
                        #if DEBUG
                        print(String(format: "[MB DEBUG] #%02d  %@ -> %@   %.2f h  |  no deduction",
                                     idx + 1, startStr, endStr, dur/3600.0))
                        #endif
                    }
                } else {
                    // Not the special title: no per-instance deduction
                    adjustedTotal += dur
                }
            }
            
            #if DEBUG
            if normTitle == specialNorm {
                print(String(format: "[MB DEBUG] Raw total: %.2f h", rawTotal/3600.0))
                print(String(format: "[MB DEBUG] Adjusted total: %.2f h", adjustedTotal/3600.0))
            }
            #endif
            
            return EventTitleGroup(id: normTitle,
                                   displayTitle: display,
                                   count: items.count,
                                   totalSeconds: adjustedTotal)
        }
        return groups.sorted { $0.displayTitle.localizedCaseInsensitiveCompare($1.displayTitle) == .orderedAscending }
    }
    
    // MARK: - Published State
    
    @Published var titleGroups: [EventTitleGroup] = []
    @Published var uniqueTitleCount: Int = 0
    @Published var dedupStrategy: DedupStrategy = .byTitle
    @Published var calendars: [CalendarItem] = []
    @Published var selectedCalendarID: String?
    @Published var dateRange: DateRange = .currentYear()
    @Published var includeAllDay = false
    
    // Outputs
    @Published var isAuthorized = false
    @Published var status: String = "Requesting access…"
    @Published var totalSeconds: TimeInterval = 0
    
    // MARK: - Dependencies
    
    private let repo: CalendarRepository
    
    init(repo: CalendarRepository? = nil) {
        self.repo = repo ?? EventKitService()
    }
    
    // MARK: - Lifecycle
    
    func bootstrap() {
        Task {
            do {
                try await repo.requestAccess()
                isAuthorized = true
                status = "Access granted."
                loadCalendars()
            } catch {
                isAuthorized = false
                status = "Access denied: \(error.localizedDescription)"
            }
        }
    }
    
    func loadCalendars() {
        let list = repo.calendars().map(CalendarItem.init)
        calendars = list
        if selectedCalendarID == nil { selectedCalendarID = list.first?.id }
    }
    
    // MARK: - Compute
    
    func calculateTotal() {
        guard let calID = selectedCalendarID,
              let ekCal = repo.calendars().first(where: { $0.calendarIdentifier == calID }) else {
            totalSeconds = 0
            status = "Select a calendar."
            return
        }
        guard dateRange.end > dateRange.start else {
            totalSeconds = 0
            status = "End date must be after start date."
            return
        }
        
        let events = repo.events(in: ekCal, interval: dateRange.asInterval)
        let base = includeAllDay ? events : events.filter { !$0.isAllDay }
        
        // One line per unique name; totals already adjusted in groups
        let groups = buildTitleGroups(from: base)
        self.titleGroups = groups
        self.uniqueTitleCount = groups.count
        totalSeconds = groups.reduce(0) { $0 + $1.totalSeconds }
        if groups.contains(where: { $0.id == normalizeTitle("MarryBrown Dandenong (PC)") }) {
            status = "Found \(groups.count) unique title(s). For \"MarryBrown Dandenong (PC)\", deducted 0.5h from each instance with duration ≥ 5h."
        } else {
            status = "Found \(groups.count) unique title(s)."
        }
    }
    
    // MARK: - Utilities
    
    /// Deduplicate exact event instances based on a stable key.
    private func dedupByInstance(_ events: [EKEvent]) -> [EKEvent] {
        var seen = Set<String>()
        return events.filter { e in
            let uid = e.calendarItemExternalIdentifier ?? e.eventIdentifier ?? "NA"
            let start = Int(e.startDate.timeIntervalSinceReferenceDate)
            let end = Int(e.endDate.timeIntervalSinceReferenceDate)
            let key = "\(uid)|\(start)|\(end)"
            if seen.contains(key) { return false }
            seen.insert(key)
            return true
        }
    }
    
    /// Merge overlapping time intervals and return total duration (no double counting overlaps).
    private func sumUnionDuration(_ events: [EKEvent]) -> TimeInterval {
        var intervals = events
            .map { DateInterval(start: $0.startDate, end: $0.endDate) }
            .filter { $0.end > $0.start }
            .sorted { $0.start < $1.start }
        
        guard !intervals.isEmpty else { return 0 }
        
        var total: TimeInterval = 0
        var current = intervals.removeFirst()
        
        for iv in intervals {
            if iv.start <= current.end {
                // Overlap → extend
                current = DateInterval(start: current.start, end: max(current.end, iv.end))
            } else {
                // Disjoint → add and move on
                total += current.duration
                current = iv
            }
        }
        total += current.duration
        return total
    }
    
    private func totalSecondsForTitle(_ events: [EKEvent], title: String) -> TimeInterval {
        let norm = normalizeTitle(title)
        return events
            .filter { normalizeTitle($0.title) == norm }
            .reduce(0) { $0 + max(0, $1.endDate.timeIntervalSince($1.startDate)) }
    }
    
    // Helper for quick binding in the view
    var totalFormatted: String { totalSeconds.asHoursMinutes }
}
