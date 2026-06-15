import SwiftUI
import Charts

struct StatusPoint: Identifiable {
    let id = UUID()
    let date: Date
    let count: Int
}

enum HistoryRange: String, CaseIterable, Identifiable {
    case day
    case week
    case month
    
    var id: String { rawValue }
    
    var displayTitle: String {
        switch self {
        case .day: return "24 Hours"
        case .week: return "1 Week"
        case .month: return "1 Month"
        }
    }
    
    func dateInterval(from now: Date = .now, calendar: Calendar = .current) -> DateInterval {
        switch self {
        case .day:
            let end = calendar.dateInterval(of: .hour, for: now)?.start ?? now
            let start = calendar.date(byAdding: .hour, value: -23, to: end)!
            return DateInterval(start: start, end: end.addingTimeInterval(3600))
        case .week:
            let end = calendar.startOfDay(for: now)
            let start = calendar.date(byAdding: .day, value: -6, to: end)!
            return DateInterval(start: start, end: end.addingTimeInterval(86400))
        case .month:
            let end = calendar.startOfDay(for: now)
            let start = calendar.date(byAdding: .day, value: -29, to: end)!
            return DateInterval(start: start, end: end.addingTimeInterval(86400))
        }
    }
}

struct StatusHistoryView: View {
    let incidents: [Incident]
    var now: Date = .now
    
    @State private var selectedRange: HistoryRange = .day
    
    private let calendar = Calendar.current
    
    private var points: [StatusPoint] {
        let interval = selectedRange.dateInterval(from: now, calendar: calendar)
        switch selectedRange {
        case .day:
            return hourlyBuckets(interval: interval)
        case .week:
            return dailyBuckets(interval: interval, dayCount: 7)
        case .month:
            return dailyBuckets(interval: interval, dayCount: 30)
        }
    }
    
    private func hourlyBuckets(interval: DateInterval) -> [StatusPoint] {
        var buckets: [Date: Int] = [:]
        for i in 0..<24 {
            if let bucketStart = calendar.date(byAdding: .hour, value: i, to: interval.start) {
                buckets[bucketStart] = 0
            }
        }
        
        for incident in incidents {
            guard let incidentDate = incidentDate(incident) else { continue }
            if incidentDate < interval.start || incidentDate >= interval.end { continue }
            let bucketStart = calendar.dateInterval(of: .hour, for: incidentDate)?.start ?? incidentDate
            if buckets[bucketStart] != nil {
                buckets[bucketStart]! += 1
            }
        }
        
        return buckets.sorted { $0.key < $1.key }
            .map { StatusPoint(date: $0.key, count: $0.value) }
    }
    
    private func dailyBuckets(interval: DateInterval, dayCount: Int) -> [StatusPoint] {
        var buckets: [Date: Int] = [:]
        for i in 0..<dayCount {
            if let bucketStart = calendar.date(byAdding: .day, value: i, to: interval.start) {
                buckets[bucketStart] = 0
            }
        }
        
        for incident in incidents {
            guard let incidentDate = incidentDate(incident) else { continue }
            if incidentDate < interval.start || incidentDate >= interval.end { continue }
            let bucketStart = calendar.startOfDay(for: incidentDate)
            if buckets[bucketStart] != nil {
                buckets[bucketStart]! += 1
            }
        }
        
        return buckets.sorted { $0.key < $1.key }
            .map { StatusPoint(date: $0.key, count: $0.value) }
    }
    
    private func incidentDate(_ incident: Incident) -> Date? {
        incident.displayDate
    }
    
    var body: some View {
        VStack {
            Picker("Range", selection: $selectedRange) {
                ForEach(HistoryRange.allCases) { range in
                    Text(range.displayTitle).tag(range)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            
            Chart {
                ForEach(points) { point in
                    BarMark(
                        x: .value("Date", point.date),
                        y: .value("Count", point.count)
                    )
                    .annotation(position: .top, alignment: .center) {
                        if point.count > 0 {
                            Text("\(point.count)")
                                .font(.caption2)
                                .foregroundColor(.primary)
                        }
                    }
                    .accessibilityLabel(Text(point.date, style: selectedRange == .day ? .time : .date))
                    .accessibilityValue("\(point.count) incident\(point.count == 1 ? "" : "s")")
                }
                
                RuleMark(x: .value("Now", now))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [5]))
                    .foregroundStyle(.red)
                    .annotation(position: .top, alignment: .leading) {
                        Text("Now")
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                    .accessibilityHidden(true)
            }
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: selectedRange == .day ? 6 : 5)) { value in
                    AxisGridLine()
                    AxisTick()
                    if let dateValue = value.as(Date.self) {
                        AxisValueLabel {
                            Text(dateLabel(for: dateValue))
                        }
                    }
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading)
            }
            .padding()
            .background(.thinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Incident history chart")
            .accessibilityHint("Shows incident counts over the selected time range: \(selectedRange.displayTitle)")
        }
    }
    
    private func dateLabel(for date: Date) -> String {
        let formatter = DateFormatter()
        switch selectedRange {
        case .day:
            formatter.dateFormat = "ha"
        case .week, .month:
            formatter.dateFormat = "MMM d"
        }
        return formatter.string(from: date)
    }
}

#Preview {
    let now = Date()
    let calendar = Calendar.current
    
    let sampleIncidents: [Incident] = [
        Incident(id: "1", name: "Incident 1", description: nil, status: "RESOLVED", impact: nil, url: nil, started: calendar.date(byAdding: .hour, value: -1, to: now), updatedAt: calendar.date(byAdding: .hour, value: -1, to: now)),
        Incident(id: "2", name: "Incident 2", description: nil, status: "RESOLVED", impact: nil, url: nil, started: calendar.date(byAdding: .hour, value: -2, to: now), updatedAt: calendar.date(byAdding: .hour, value: -2, to: now)),
        Incident(id: "3", name: "Incident 3", description: nil, status: "RESOLVED", impact: nil, url: nil, started: calendar.date(byAdding: .day, value: -1, to: now), updatedAt: calendar.date(byAdding: .day, value: -1, to: now)),
        Incident(id: "4", name: "Incident 4", description: nil, status: "RESOLVED", impact: nil, url: nil, started: calendar.date(byAdding: .day, value: -3, to: now), updatedAt: calendar.date(byAdding: .day, value: -3, to: now)),
        Incident(id: "5", name: "Incident 5", description: nil, status: "RESOLVED", impact: nil, url: nil, started: calendar.date(byAdding: .day, value: -10, to: now), updatedAt: calendar.date(byAdding: .day, value: -10, to: now)),
        Incident(id: "6", name: "Incident 6", description: nil, status: "RESOLVED", impact: nil, url: nil, started: calendar.date(byAdding: .day, value: -15, to: now), updatedAt: calendar.date(byAdding: .day, value: -15, to: now)),
        Incident(id: "7", name: "Incident 7", description: nil, status: "RESOLVED", impact: nil, url: nil, started: calendar.date(byAdding: .day, value: -29, to: now), updatedAt: calendar.date(byAdding: .day, value: -29, to: now)),
        Incident(id: "8", name: "Incident 8", description: nil, status: "RESOLVED", impact: nil, url: nil, started: calendar.date(byAdding: .minute, value: -5, to: now), updatedAt: calendar.date(byAdding: .minute, value: -5, to: now)),
        Incident(id: "9", name: "Incident 9", description: nil, status: "RESOLVED", impact: nil, url: nil, started: now, updatedAt: now),
        Incident(id: "10", name: "Incident 10", description: nil, status: "RESOLVED", impact: nil, url: nil, started: calendar.date(byAdding: .hour, value: -23, to: now), updatedAt: calendar.date(byAdding: .hour, value: -23, to: now)),
        Incident(id: "11", name: "Incident 11", description: nil, status: "RESOLVED", impact: nil, url: nil, started: calendar.date(byAdding: .day, value: -7, to: now), updatedAt: calendar.date(byAdding: .day, value: -7, to: now)),
    ]
    
    StatusHistoryView(incidents: sampleIncidents, now: now)
        .frame(height: 300)
        .padding()
}
