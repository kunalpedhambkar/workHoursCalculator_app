//
//  CalendarItem.swift
//  Work Hours Calculator
//
//  Created by Kunal Rajesh Pedhambkar on 7/11/2025.
//


import Foundation
import SwiftUI
import EventKit

struct CalendarItem: Identifiable, Equatable {
    let id: String               // EKCalendar.calendarIdentifier
    let title: String
    let color: Color

    init(_ cal: EKCalendar) {
        self.id = cal.calendarIdentifier
        self.title = cal.title
        self.color = Color(cal.cgColor ?? CGColor(gray: 0.5, alpha: 1))
    }
}

struct DateRange {
    var start: Date
    var end: Date

    static func currentYear() -> DateRange {
        let cal = Calendar.current
        let y = cal.component(.year, from: Date())
        let start = cal.date(from: DateComponents(year: y, month: 1, day: 1))!
        let end   = cal.date(from: DateComponents(year: y, month: 12, day: 31, hour: 23, minute: 59, second: 59))!
        return .init(start: start, end: end)
    }

    var asInterval: DateInterval { .init(start: start, end: end) }
}

extension TimeInterval {
    var asHoursMinutes: String {
        guard self > 0 else { return "0h 0m" }
        let hours = Int(self / 3600)
        let minutes = Int((self.truncatingRemainder(dividingBy: 3600)) / 60)
        return "\(hours)h \(minutes)m"
    }
}