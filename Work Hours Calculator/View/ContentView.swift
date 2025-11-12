import SwiftUI

struct ContentView: View {
    @StateObject private var vm = CalendarDurationViewModel()

    var body: some View {
        NavigationView {
            Form {
                Section("Permission") {
                    HStack {
                        Label(vm.isAuthorized ? "Authorized" : "Not Authorized",
                              systemImage: vm.isAuthorized ? "checkmark.shield" : "xmark.shield")
                        Spacer()
                        Button(vm.isAuthorized ? "Granted" : "Request Access") {
                            vm.bootstrap()
                        }
                        .disabled(vm.isAuthorized)
                    }
                    Text(vm.status).font(.footnote).foregroundStyle(.secondary)
                }

                Section("Calendar") {
                    if $vm.calendars.isEmpty {
                        Text("No calendars found or access not granted.")
                            .foregroundStyle(.secondary)
                    } else {
                        Picker("Choose Calendar", selection: $vm.selectedCalendarID) {
                            ForEach(vm.calendars) { cal in
                                HStack {
                                    Circle().fill(cal.color).frame(width: 10, height: 10)
                                    Text(cal.title)
                                }
                                .tag(Optional(cal.id))
                            }
                        }
                    }
                    Toggle("Include all-day events", isOn: $vm.includeAllDay)
                }
                
                Section("Date Range") {
                    DatePicker("Start", selection: Binding(
                        get: { vm.dateRange.start },
                        set: { vm.dateRange.start = $0 }
                    ), displayedComponents: [.date])

                    DatePicker("End", selection: Binding(
                        get: { vm.dateRange.end },
                        set: { vm.dateRange.end = $0 }
                    ), displayedComponents: [.date])
                }
                
                Section("Events in Date Range") {
                    if vm.titleGroups.isEmpty {
                        Text("No events in the selected range.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(vm.titleGroups) { group in
                            HStack(alignment: .firstTextBaseline) {
                                Text(group.displayTitle)
                                    .lineLimit(2)
                                Spacer(minLength: 12)
                                VStack(alignment: .trailing, spacing: 2) {
                                    Text(group.totalSeconds.asHoursMinutes)
                                        .font(.subheadline)
                                        .bold()
                                    Text("\(group.count) instance\(group.count == 1 ? "" : "s")")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                        .monospacedDigit()
                                }
                            }
                            .padding(.vertical, 6)
                        }
                    }
                }

                Section("Total Duration") {
                    HStack {
                        Text("Sum of event durations")
                        Spacer()
                        Text(vm.totalFormatted).bold()
                    }
                    Button("Calculate") {
                        vm.calculateTotal()
                    }
                    .buttonStyle(.borderedProminent)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                }
            }
            .navigationTitle("Calendar Time Total")
            .onAppear { if !vm.isAuthorized { vm.bootstrap() } }
        }
    }
}

struct CalendarTimeTotalApp: App {
    var body: some Scene {
        WindowGroup { ContentView() }
    }
}
