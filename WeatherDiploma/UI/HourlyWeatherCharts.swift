import Charts
import SwiftUI

/// Plain values keep Realm/Core Data and UIKit objects out of Swift Charts.
struct HourlyChartPoint: Identifiable {
    let time: Date
    let value: Double

    var id: Date { time }
}

struct HourlyChartDataset {
    let temperatures: [HourlyChartPoint]
    let precipitationChance: [HourlyChartPoint]

    init(hours: [HourWeather], settings: WeatherSettings) {
        temperatures = hours.compactMap { hour in
            guard let temperature = hour.temperature, temperature.isFinite else {
                return nil
            }
            let value = settings.fahrenheit
                ? temperature * 1.8 + 32
                : temperature
            return HourlyChartPoint(time: hour.time, value: value)
        }

        precipitationChance = hours.compactMap { hour in
            guard let probability = hour.probability, probability.isFinite else {
                return nil
            }
            return HourlyChartPoint(
                time: hour.time,
                value: min(100, max(0, probability))
            )
        }
    }
}

/// Swift Charts is hosted inside the existing UIKit detail controller.
/// Both plots use actual hourly forecast values and skip missing measurements.
struct HourlyWeatherCharts: View {
    let hours: [HourWeather]
    let timezone: String
    let settings: WeatherSettings

    private var dataset: HourlyChartDataset {
        HourlyChartDataset(hours: hours, settings: settings)
    }

    private var accent: Color { Color(uiColor: Palette.accent) }
    private var plotBackground: Color { Color(uiColor: Palette.card) }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 10) {
                Text("График температуры, \(settings.fahrenheit ? "°F" : "°C")")
                    .font(.headline)
                    .accessibilityAddTraits(.isHeader)

                if dataset.temperatures.isEmpty {
                    noData
                } else {
                    Chart(dataset.temperatures) { point in
                        LineMark(
                            x: .value("Время", point.time),
                            y: .value("Температура", point.value)
                        )
                        .interpolationMethod(.linear)
                        .lineStyle(StrokeStyle(lineWidth: 2.5))
                        .foregroundStyle(accent)

                        PointMark(
                            x: .value("Время", point.time),
                            y: .value("Температура", point.value)
                        )
                        .symbolSize(18)
                        .foregroundStyle(accent)
                    }
                    .chartXAxis {
                        AxisMarks(values: .stride(by: .hour, count: 4)) {
                            AxisGridLine()
                            AxisValueLabel(format: .dateTime.hour())
                        }
                    }
                    .chartYAxis {
                        AxisMarks(position: .leading) {
                            AxisGridLine()
                            AxisValueLabel()
                        }
                    }
                    .chartLegend(.hidden)
                    .frame(height: 156)
                    .accessibilityLabel(
                        "Температура по часам, \(settings.fahrenheit ? "градусы Фаренгейта" : "градусы Цельсия")"
                    )
                    .accessibilityIdentifier("hourly-temperature-chart")
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(plotBackground, in: RoundedRectangle(cornerRadius: 16))

            VStack(alignment: .leading, spacing: 10) {
                Text("Вероятность осадков, %")
                    .font(.headline)
                    .accessibilityAddTraits(.isHeader)

                if dataset.precipitationChance.isEmpty {
                    noData
                } else {
                    Chart(dataset.precipitationChance) { point in
                        BarMark(
                            x: .value("Время", point.time),
                            y: .value("Вероятность", point.value)
                        )
                        .foregroundStyle(accent.opacity(0.78))
                    }
                    .chartYScale(domain: 0.0...100.0)
                    .chartXAxis {
                        AxisMarks(values: .stride(by: .hour, count: 4)) {
                            AxisGridLine()
                            AxisValueLabel(format: .dateTime.hour())
                        }
                    }
                    .chartYAxis {
                        AxisMarks(position: .leading, values: [0.0, 50.0, 100.0]) {
                            AxisGridLine()
                            AxisValueLabel()
                        }
                    }
                    .chartLegend(.hidden)
                    .frame(height: 130)
                    .accessibilityLabel("Вероятность осадков по часам, в процентах")
                    .accessibilityIdentifier("hourly-precipitation-chart")
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(plotBackground, in: RoundedRectangle(cornerRadius: 16))
        }
        .padding(.vertical, 8)
        .environment(\.timeZone, TimeZone(identifier: timezone) ?? .gmt)
    }

    private var noData: some View {
        Text("Нет данных для построения графика")
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, minHeight: 80, alignment: .center)
    }

}
