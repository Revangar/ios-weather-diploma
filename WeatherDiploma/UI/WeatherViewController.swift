import UIKit

final class WeatherViewController: UITableViewController {
    let city: City
    private let repository: WeatherRepository
    private let defaults: UserDefaults
    private var forecast: Forecast?
    private var refreshTask: Task<Void, Never>?
    private var requestID = UUID()
    private var state = "Загрузка сохранённых данных…"
    private var pendingHeader: UIView?
    private var settings: WeatherSettings { .load(defaults) }
    var openHours: ((City, Forecast, Int) -> Void)?
    var openDay: ((City, Forecast, Int) -> Void)?

    init(city: City, repository: WeatherRepository, defaults: UserDefaults) {
        self.city = city
        self.repository = repository
        self.defaults = defaults
        super.init(style: .plain)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        tableView.separatorStyle = .none
        tableView.register(DailyCell.self, forCellReuseIdentifier: DailyCell.reuseID)
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 90
        tableView.tableFooterView = attribution()
        tableView.accessibilityIdentifier = "weather-table"
        refreshControl = UIRefreshControl()
        refreshControl?.addTarget(self, action: #selector(refresh), for: .valueChanged)
        registerForTraitChanges([UITraitPreferredContentSizeCategory.self]) { (controller: WeatherViewController, _: UITraitCollection) in
            controller.render()
        }
        render()
    }
    override func viewDidLayoutSubviews() { super.viewDidLayoutSubviews(); sizeHeader() }
    override func viewWillAppear(_ animated: Bool) { super.viewWillAppear(animated); render() }
    override func viewDidAppear(_ animated: Bool) { super.viewDidAppear(animated); start() }
    override func viewDidDisappear(_ animated: Bool) { super.viewDidDisappear(animated); stop() }
    func start() {
        guard refreshTask == nil else { return }
        let requestID = UUID()
        self.requestID = requestID
        refreshTask = Task { [weak self] in
            guard let self else { return }
            defer {
                if self.requestID == requestID { self.refreshTask = nil; self.refreshControl?.endRefreshing() }
            }
            do {
                if self.forecast == nil, let cached = try await self.repository.cached(for: self.city) {
                    try Task.checkCancellation()
                    self.forecast = cached
                    self.state = "Кэш · обновляем из сети…"
                    self.render()
                }
                try Task.checkCancellation()
                self.state = self.forecast == nil ? "Получаем прогноз…" : "Кэш · обновляем из сети…"
                self.render()
                let fresh = try await self.repository.refresh(for: self.city)
                try Task.checkCancellation()
                self.forecast = fresh
                self.state = "Обновлено \(self.settings.time(fresh.fetchedAt, zone: fresh.timezone))"
                self.render()
            } catch is CancellationError { }
            catch let error as URLError where error.code == .cancelled { }
            catch {
                guard self.requestID == requestID, !Task.isCancelled else { return }
                self.state = self.forecast == nil
                    ? "Не удалось загрузить прогноз. \(WeatherError.message(for: error))"
                    : "Сохранённый прогноз · \(WeatherError.message(for: error))"
                self.render()
            }
        }
    }
    func stop() { refreshTask?.cancel(); refreshTask = nil; requestID = UUID() }
    @objc private func refresh() { start() }

    private func render() {
        guard isViewLoaded else { return }
        tableView.tableFooterView = attribution()
        let status = label(state, style: .caption1, color: .secondaryLabel)
        status.accessibilityIdentifier = "weather-status"
        let country = label(city.country, style: .caption1, color: .secondaryLabel)
        country.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        let metadata = stack([country, status], axis: traitCollection.preferredContentSizeCategory.isAccessibilityCategory ? .vertical : .horizontal, spacing: 8)
        let column = stack([metadata], spacing: 8)
        if let forecast {
            if forecast.isStale {
                column.addArrangedSubview(label("Данные устарели · \(WeatherFormat.date(forecast.fetchedAt, zone: forecast.timezone, format: "dd.MM HH:mm"))", style: .caption1, color: .systemOrange))
            }
            column.addArrangedSubview(hero(forecast))
            let details = UIButton(type: .system)
            details.setTitle("Подробнее на 24 часа →", for: .normal)
            details.titleLabel?.font = .preferredFont(forTextStyle: .headline)
            details.titleLabel?.adjustsFontForContentSizeCategory = true
            details.accessibilityIdentifier = "open-hours"
            details.heightAnchor.constraint(greaterThanOrEqualToConstant: 44).isActive = true
            details.titleLabel?.numberOfLines = 0
            details.addAction(UIAction { [weak self] _ in
                guard let self else { return }; self.openHours?(self.city, forecast, 0)
            }, for: .touchUpInside)
            column.addArrangedSubview(details)
            let strip = HourStrip()
            strip.configure(hours: forecast.next24, zone: forecast.timezone, settings: settings, selected: 0)
            strip.onSelect = { [weak self] index in
                guard let self else { return }; self.openHours?(self.city, forecast, index)
            }
            column.addArrangedSubview(strip)
            let more = UIButton(type: .system)
            more.setTitle("25 дней ⓘ", for: .normal)
            more.accessibilityIdentifier = "forecast-25"
            more.heightAnchor.constraint(greaterThanOrEqualToConstant: 44).isActive = true
            more.addAction(UIAction { [weak self] _ in
                let alert = UIAlertController(title: "Доступно 7 дней", message: "Open-Meteo предоставляет прогноз максимум на 16 дней. Надёжный 25-дневный прогноз недоступен; приложение показывает только реальные данные на 7 дней.", preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "Понятно", style: .default))
                self?.present(alert, animated: true)
            }, for: .touchUpInside)
            let heading = stack([label("Ежедневный прогноз", style: .headline), more],
                                axis: traitCollection.preferredContentSizeCategory.isAccessibilityCategory ? .vertical : .horizontal)
            heading.distribution = .fill
            more.setContentHuggingPriority(.required, for: .horizontal)
            column.addArrangedSubview(heading)
        } else {
            column.addArrangedSubview(actionButton("Повторить загрузку", id: "retry-weather") { [weak self] in self?.start() })
        }
        let container = UIView()
        column.pin(in: container, inset: 12)
        // A page can load before UIPageViewController gives it a nonzero width.
        // Measure before installing, so UITableView never receives a zero-height header
        // or a placeholder width that conflicts with its encapsulated layout constraints.
        pendingHeader = container
        sizeHeader()
        tableView.reloadData()
    }

    private func hero(_ forecast: Forecast) -> UIView {
        let current = forecast.current
        let card = SunCard()
        card.backgroundColor = Palette.blue
        card.layer.cornerRadius = 16
        card.clipsToBounds = true
        card.accessibilityIdentifier = "current-weather-card"
        let icon = UIImageView(image: UIImage(systemName: WeatherCode.symbol(current.code, isDay: current.isDay)))
        icon.tintColor = .systemYellow
        icon.contentMode = .scaleAspectFit
        icon.heightAnchor.constraint(equalToConstant: 32).isActive = true
        icon.widthAnchor.constraint(equalToConstant: 38).isActive = true
        let temperature = label(settings.temperature(current.temperature), style: .largeTitle, color: .white)
        temperature.font = UIFontMetrics(forTextStyle: .largeTitle).scaledFont(for: .systemFont(ofSize: 42, weight: .medium))
        temperature.accessibilityIdentifier = "current-temperature"
        let condition = label(WeatherCode.description(current.code), style: .headline, color: .white)
        let feels = label("По ощущению \(settings.temperature(current.feelsLike))", style: .caption1, color: .white)
        let now = label("\(WeatherFormat.date(Date(), zone: forecast.timezone, format: "EEE, d MMMM")) · \(settings.time(Date(), zone: forecast.timezone))", style: .footnote, color: .white)
        let metrics = label("💧 \(WeatherFormat.number(current.humidity, suffix: "%")) · \(WeatherFormat.rain(current.precipitation)) · Ветер \(settings.wind(current.wind))", style: .footnote, color: .white)
        metrics.accessibilityLabel = "Влажность \(WeatherFormat.number(current.humidity, suffix: "%")), осадки \(WeatherFormat.rain(current.precipitation)), ветер \(settings.wind(current.wind))"
        let temperatureRow = stack([UIView(), icon, temperature, UIView()], axis: .horizontal, spacing: 8)
        temperatureRow.alignment = .center
        temperatureRow.arrangedSubviews.first!.widthAnchor.constraint(equalTo: temperatureRow.arrangedSubviews.last!.widthAnchor).isActive = true
        let column = stack([temperatureRow, condition, feels, metrics, now], spacing: 6)
        if let day = forecast.days.first {
            let sunrise = day.sunrise.map { settings.time($0, zone: forecast.timezone) } ?? "—"
            let sunset = day.sunset.map { settings.time($0, zone: forecast.timezone) } ?? "—"
            let range = label("\(settings.temperature(day.low)) / \(settings.temperature(day.high))", style: .footnote, color: .white)
            range.textAlignment = .center
            column.insertArrangedSubview(range, at: 0)
            column.addArrangedSubview(label("☀︎ ↑ \(sunrise)   ↓ \(sunset) · Световой день \(WeatherFormat.duration(day.daylight))", style: .caption1, color: .white))
        }
        column.arrangedSubviews.compactMap { $0 as? UILabel }.forEach { $0.textAlignment = .center }
        column.pin(in: card, inset: 16)
        return card
    }
    private func sizeHeader() {
        guard let header = pendingHeader ?? tableView.tableHeaderView, tableView.bounds.width > 0 else { return }
        let width = tableView.bounds.width
        let height = header.systemLayoutSizeFitting(CGSize(width: width, height: 0), withHorizontalFittingPriority: .required,
                                                   verticalFittingPriority: .fittingSizeLevel).height
        if pendingHeader != nil || abs(header.frame.height - height) > 0.5 || header.frame.width != width {
            header.frame = CGRect(x: 0, y: 0, width: width, height: height)
            pendingHeader = nil
            tableView.tableHeaderView = header
        }
    }
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { forecast?.days.count ?? 0 }
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: DailyCell.reuseID, for: indexPath) as! DailyCell
        if let forecast { cell.configure(forecast.days[indexPath.row], zone: forecast.timezone, settings: settings, index: indexPath.row) }
        return cell
    }
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        if let forecast { openDay?(city, forecast, indexPath.row) }
    }
    private func attribution() -> UIView {
        let button = UIButton(type: .system)
        button.setTitle("Данные: Open-Meteo · CC BY 4.0 · GeoNames", for: .normal)
        button.titleLabel?.font = .preferredFont(forTextStyle: .caption2)
        button.titleLabel?.adjustsFontForContentSizeCategory = true
        button.titleLabel?.numberOfLines = 0
        button.addAction(UIAction { _ in UIApplication.shared.open(URL(string: "https://open-meteo.com/")!) }, for: .touchUpInside)
        button.frame.size.height = UIFontMetrics.default.scaledValue(for: 58)
        return button
    }
}
