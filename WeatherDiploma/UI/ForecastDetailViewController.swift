import UIKit
import SwiftUI
import Charts

final class ForecastDetailViewController: UITableViewController {
    private let city: City
    private let forecast: Forecast
    private let settings: WeatherSettings
    private let dailyMode: Bool
    private var selectedDay: Int
    private var selectedHour: Int
    private weak var dayScroll: UIScrollView?
    private weak var selectedDayButton: UIButton?
    private var shouldAlignDay = false
    private var hours: [HourWeather] { dailyMode ? forecast.hours(on: forecast.days[selectedDay]) : forecast.next24 }

    init(city: City, forecast: Forecast, settings: WeatherSettings, day: Int? = nil, hour: Int = 0) {
        self.city = city
        self.forecast = forecast
        self.settings = settings
        dailyMode = day != nil
        selectedDay = day ?? 0
        selectedHour = hour
        super.init(style: .insetGrouped)
        title = dailyMode ? "Дневная погода" : "Прогноз на 24 часа"
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.accessibilityIdentifier = dailyMode ? "daily-detail" : "hourly-detail"
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "detail")
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "charts")
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 160
        registerForTraitChanges([UITraitPreferredContentSizeCategory.self]) { (controller: ForecastDetailViewController, _: UITraitCollection) in
            controller.renderHeader()
            controller.tableView.reloadData()
        }
        renderHeader()
    }
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        guard let header = tableView.tableHeaderView else { return }
        let height = header.systemLayoutSizeFitting(CGSize(width: tableView.bounds.width, height: 0),
            withHorizontalFittingPriority: .required, verticalFittingPriority: .fittingSizeLevel).height
        if abs(header.frame.height - height) > 1 || header.frame.width != tableView.bounds.width {
            header.frame = CGRect(x: 0, y: 0, width: tableView.bounds.width, height: height)
            tableView.tableHeaderView = header
        }
        if shouldAlignDay, let scroll = dayScroll, let selectedDayButton, scroll.bounds.width > 0 {
            shouldAlignDay = false
            scroll.layoutIfNeeded()
            scroll.scrollRectToVisible(selectedDayButton.frame.insetBy(dx: -8, dy: 0), animated: false)
        }
    }
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if !dailyMode && selectedHour > 0 && hours.indices.contains(selectedHour) {
            tableView.scrollToRow(at: IndexPath(row: selectedHour, section: 1), at: .middle, animated: false)
        }
    }
    private func renderHeader() {
        let title = label(city.name, style: .title2)
        let zone = label("\(forecast.timezone) · \(WeatherFormat.date(forecast.fetchedAt, zone: forecast.timezone, format: "dd.MM HH:mm"))", style: .caption1, color: .secondaryLabel)
        let column = stack([title, zone])
        if dailyMode {
            let scroll = UIScrollView()
            dayScroll = scroll
            shouldAlignDay = true
            scroll.showsHorizontalScrollIndicator = false
            let days = stack([], axis: .horizontal)
            days.translatesAutoresizingMaskIntoConstraints = false
            scroll.addSubview(days)
            NSLayoutConstraint.activate([
                days.leadingAnchor.constraint(equalTo: scroll.contentLayoutGuide.leadingAnchor),
                days.trailingAnchor.constraint(equalTo: scroll.contentLayoutGuide.trailingAnchor),
                days.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor),
                days.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor),
                days.heightAnchor.constraint(equalTo: scroll.frameLayoutGuide.heightAnchor),
                scroll.heightAnchor.constraint(equalToConstant: UIFontMetrics.default.scaledValue(for: 48))
            ])
            for (index, day) in forecast.days.enumerated() {
                var config = index == selectedDay ? UIButton.Configuration.filled() : .tinted()
                config.title = WeatherFormat.date(day.time, zone: forecast.timezone, format: "dd.MM EEE")
                config.baseBackgroundColor = Palette.blue
                config.baseForegroundColor = index == selectedDay ? .white : Palette.accent
                let button = UIButton(configuration: config, primaryAction: UIAction { [weak self] _ in
                    guard let self else { return }
                    self.selectedDay = index
                    self.selectedHour = 0
                    self.renderHeader()
                    self.tableView.reloadData()
                })
                button.accessibilityIdentifier = "select-day-\(index)"
                button.accessibilityTraits = index == selectedDay ? [.button, .selected] : [.button]
                if index == selectedDay { selectedDayButton = button }
                days.addArrangedSubview(button)
            }
            column.addArrangedSubview(scroll)
        }
        let strip = HourStrip()
        strip.configure(hours: hours, zone: forecast.timezone, settings: settings, selected: selectedHour)
        strip.onSelect = { [weak self] index in
            guard let self else { return }
            self.selectedHour = index
            self.tableView.reloadData()
            let row = self.dailyMode ? index + 3 : index
            self.tableView.scrollToRow(at: IndexPath(row: row, section: 1), at: .middle, animated: true)
        }
        column.addArrangedSubview(strip)
        let container = UIView()
        column.pin(in: container, inset: 18)
        tableView.tableHeaderView = container
        view.setNeedsLayout()
    }
    override func numberOfSections(in tableView: UITableView) -> Int { 2 }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        section == 0 ? 1 : hours.count + (dailyMode ? 3 : 0)
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if indexPath.section == 0 {
            let cell = tableView.dequeueReusableCell(withIdentifier: "charts", for: indexPath)
            cell.selectionStyle = .none
            cell.backgroundColor = .clear
            cell.contentConfiguration = UIHostingConfiguration {
                HourlyForecastCharts(
                    hours: hours,
                    timeZone: forecast.timezone,
                    settings: settings
                )
            }
            .margins(.all, 8)
            cell.accessibilityIdentifier = "forecast-charts"
            return cell
        }

        let cell = tableView.dequeueReusableCell(withIdentifier: "detail", for: indexPath)
        var config = cell.defaultContentConfiguration()
        config.textProperties.numberOfLines = 0
        config.secondaryTextProperties.numberOfLines = 0
        cell.selectionStyle = .none
        cell.backgroundColor = Palette.card
        if dailyMode && indexPath.row < 3 {
            let day = forecast.days[selectedDay]
            if indexPath.row < 2 {
                let daytime = indexPath.row == 0
                // A representative real forecast hour, never a fabricated day/night aggregate.
                let group = hours.filter { $0.isDay == daytime }
                let hour = group.min { abs(localHour($0.time) - (daytime ? 14 : 2)) < abs(localHour($1.time) - (daytime ? 14 : 2)) }
                config.text = daytime ? "День · почасовой прогноз" : "Ночь · почасовой прогноз"
                if let hour {
                    config.secondaryText = "\(settings.time(hour.time, zone: forecast.timezone)) · \(settings.temperature(hour.temperature)) · \(WeatherCode.description(hour.code))\nПо ощущению \(settings.temperature(hour.feelsLike))\nВетер \(settings.wind(hour.wind))\nВероятность осадков \(WeatherFormat.number(hour.probability, suffix: "%"))\nОблачность \(WeatherFormat.number(hour.cloud, suffix: "%"))"
                    config.image = UIImage(systemName: WeatherCode.symbol(hour.code, isDay: hour.isDay))
                } else {
                    config.secondaryText = "В этом дне нет часов с таким освещением (полярный день/ночь)."
                }
            } else {
                config.text = "Солнце · \(WeatherFormat.duration(day.daylight))"
                let rise = day.sunrise.map { settings.time($0, zone: forecast.timezone) } ?? "—"
                let set = day.sunset.map { settings.time($0, zone: forecast.timezone) } ?? "—"
                config.secondaryText = "Восход \(rise) · Закат \(set)\nУФ-индекс, максимум \(WeatherFormat.number(day.uv, suffix: ""))\nОсадки за день \(WeatherFormat.rain(day.precipitation))\nМаксимальный ветер \(settings.wind(day.wind))"
                config.image = UIImage(systemName: "sun.max.fill")
            }
        } else {
            let index = indexPath.row - (dailyMode ? 3 : 0)
            let hour = hours[index]
            config.text = "\(WeatherFormat.date(hour.time, zone: forecast.timezone, format: "EEE, dd.MM")) · \(settings.time(hour.time, zone: forecast.timezone)) · \(settings.temperature(hour.temperature))"
            config.secondaryText = "\(WeatherCode.description(hour.code)) · по ощущению \(settings.temperature(hour.feelsLike))\nВетер \(settings.wind(hour.wind)) · \(WeatherFormat.number(hour.direction, suffix: "°"))\nОсадки \(WeatherFormat.rain(hour.precipitation)) · вероятность \(WeatherFormat.number(hour.probability, suffix: "%"))\nВлажность \(WeatherFormat.number(hour.humidity, suffix: "%")) · облачность \(WeatherFormat.number(hour.cloud, suffix: "%"))"
            config.image = UIImage(systemName: WeatherCode.symbol(hour.code, isDay: hour.isDay))
            cell.backgroundColor = index == selectedHour ? Palette.blue.withAlphaComponent(0.18) : Palette.card
            cell.accessibilityIdentifier = "detail-hour-\(index)"
        }
        config.imageProperties.tintColor = Palette.accent
        cell.contentConfiguration = config
        return cell
    }
    private func localHour(_ date: Date) -> Int {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: forecast.timezone) ?? .gmt
        return calendar.component(.hour, from: date)
    }
}


// MARK: - Swift Charts hosted in the existing UIKit table view

private struct HourlyChartSample: Identifiable {
    let time: Date
    let value: Double
    var id: Date { time }
}

private struct HourlyForecastCharts: View {
    let hours: [HourWeather]
    let timeZone: String
    let settings: WeatherSettings

    private var temperatureSeries: [HourlyChartSample] {
        hours.compactMap { hour in
            guard let temperature = hour.temperature, temperature.isFinite else { return nil }
            return HourlyChartSample(
                time: hour.time,
                value: settings.fahrenheit ? temperature * 1.8 + 32 : temperature
            )
        }
    }

    private var precipitationSeries: [HourlyChartSample] {
        hours.compactMap { hour in
            guard let probability = hour.probability, probability.isFinite else { return nil }
            return HourlyChartSample(
                time: hour.time,
                value: min(100, max(0, probability))
            )
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if !temperatureSeries.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Температура · " + (settings.fahrenheit ? "°F" : "°C"))
                        .font(.headline)
                    Chart(temperatureSeries) { sample in
                        LineMark(
                            x: .value("Время", sample.time),
                            y: .value("Температура", sample.value)
                        )
                        .interpolationMethod(.catmullRom)
                        .foregroundStyle(Color(uiColor: Palette.accent))
                    }
                    .chartXAxis {
                        AxisMarks(values: .stride(by: .hour, count: 4)) { _ in
                            AxisGridLine()
                            AxisValueLabel(format: .dateTime.hour().minute())
                        }
                    }
                    .chartYAxis {
                        AxisMarks(position: .leading) {
                            AxisGridLine()
                            AxisValueLabel()
                        }
                    }
                    .frame(height: 160)
                    .accessibilityIdentifier("temperature-chart")
                    .accessibilityLabel("График температуры по часам")
                }
            }

            if !precipitationSeries.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Вероятность осадков · %")
                        .font(.headline)
                    Chart(precipitationSeries) { sample in
                        BarMark(
                            x: .value("Время", sample.time),
                            y: .value("Вероятность осадков", sample.value)
                        )
                        .foregroundStyle(Color(uiColor: Palette.accent).opacity(0.8))
                    }
                    .chartYScale(domain: 0.0...100.0)
                    .chartXAxis {
                        AxisMarks(values: .stride(by: .hour, count: 4)) { _ in
                            AxisGridLine()
                            AxisValueLabel(format: .dateTime.hour().minute())
                        }
                    }
                    .chartYAxis {
                        AxisMarks(position: .leading, values: [0, 25, 50, 75, 100]) {
                            AxisGridLine()
                            AxisValueLabel()
                        }
                    }
                    .frame(height: 115)
                    .accessibilityIdentifier("precipitation-chart")
                    .accessibilityLabel("График вероятности осадков по часам")
                }
            }

            if temperatureSeries.isEmpty && precipitationSeries.isEmpty {
                Text("Нет данных для графиков")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(uiColor: Palette.card), in: RoundedRectangle(cornerRadius: 12))
        .environment(\.locale, Locale(identifier: "ru_RU"))
        .environment(\.timeZone, TimeZone(identifier: timeZone) ?? .gmt)
    }
}
