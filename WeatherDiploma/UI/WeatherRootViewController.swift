import UIKit

final class WeatherRootViewController: UIViewController, UIPageViewControllerDataSource, UIPageViewControllerDelegate {
    private let repository: WeatherRepository
    private let defaults: UserDefaults
    private let geocoding: GeocodingService
    private let location = LocationService()
    private let pager = UIPageViewController(transitionStyle: .scroll, navigationOrientation: .horizontal)
    private let dots = UIPageControl()
    private let pageLabel = label(style: .caption1, color: .secondaryLabel)
    private let empty = UIView()
    private var cities: [City] = []
    private var pages: [WeatherViewController] = []
    private var index = 0
    private var searchTask: Task<Void, Never>?
    private var busy = false
    private var addButton: UIBarButtonItem!
    init(repository: WeatherRepository, defaults: UserDefaults, geocoding: GeocodingService = GeocodingService()) {
        self.repository = repository
        self.defaults = defaults
        self.geocoding = geocoding
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        title = "Погода"
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--fixture-network") {
            navigationItem.prompt = "Тестовые данные · UI-проверка"
        }
        #endif
        let settings = UIBarButtonItem(image: UIImage(systemName: "line.3.horizontal"), primaryAction: UIAction { [weak self] _ in self?.showSettings() })
        settings.accessibilityLabel = "Настройки"
        settings.accessibilityIdentifier = "open-settings"
        navigationItem.leftBarButtonItem = settings
        addButton = UIBarButtonItem(image: UIImage(systemName: "plus.circle"), primaryAction: UIAction { [weak self] _ in self?.promptCity() })
        addButton.accessibilityLabel = "Добавить город"
        addButton.accessibilityIdentifier = "add-city"
        navigationItem.rightBarButtonItem = addButton
        dots.currentPageIndicatorTintColor = Palette.accent
        dots.pageIndicatorTintColor = .systemGray3
        dots.addTarget(self, action: #selector(selectDot), for: .valueChanged)
        pageLabel.textAlignment = .center
        pageLabel.accessibilityIdentifier = "city-indicator"
        let heading = stack([dots, pageLabel], spacing: 0)
        heading.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(heading)
        addChild(pager)
        pager.view.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(pager.view)
        pager.didMove(toParent: self)
        pager.dataSource = self
        pager.delegate = self
        NSLayoutConstraint.activate([
            heading.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            heading.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
            heading.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
            pager.view.topAnchor.constraint(equalTo: heading.bottomAnchor, constant: 4),
            pager.view.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
            pager.view.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
            pager.view.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor)
        ])
        empty.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(empty)
        NSLayoutConstraint.activate([
            empty.topAnchor.constraint(equalTo: heading.bottomAnchor), empty.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            empty.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor), empty.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor)
        ])
        let text = label("Ваш прогноз начинается с города", style: .title2)
        text.textAlignment = .center
        let note = label("Нажмите «+» и добавьте город. Геопозиция для этого не нужна.", style: .body, color: .secondaryLabel)
        note.textAlignment = .center
        let button = actionButton("+  Добавить город", id: "empty-add-city") { [weak self] in self?.promptCity() }
        let column = stack([text, note, button], spacing: 22)
        column.translatesAutoresizingMaskIntoConstraints = false
        empty.addSubview(column)
        NSLayoutConstraint.activate([
            column.centerYAnchor.constraint(equalTo: empty.centerYAnchor),
            column.leadingAnchor.constraint(equalTo: empty.leadingAnchor, constant: 28),
            column.trailingAnchor.constraint(equalTo: empty.trailingAnchor, constant: -28)
        ])
        Task { await restore() }
    }
    private func restore() async {
        do {
            cities = try await repository.cities()
            index = cities.firstIndex { $0.id == defaults.string(forKey: "selectedCity") } ?? 0
            rebuild()
            if !defaults.bool(forKey: "onboarded") {
                let onboarding = OnboardingViewController()
                onboarding.modalPresentationStyle = .fullScreen
                onboarding.onFinish = { [weak self, weak onboarding] useLocation in
                    guard let self else { return }
                    self.defaults.set(true, forKey: "onboarded")
                    onboarding?.dismiss(animated: true) { if useLocation { self.locate() } }
                }
                present(onboarding, animated: true)
            }
        } catch { showError(error.localizedDescription) }
    }
    private func rebuild() {
        pages.forEach { $0.stop() }
        pages = cities.map { city in
            let page = WeatherViewController(city: city, repository: repository, defaults: defaults)
            page.openHours = { [weak self] city, forecast, hour in
                guard let self else { return }
                self.navigationController?.pushViewController(ForecastDetailViewController(city: city, forecast: forecast,
                    settings: .load(self.defaults), hour: hour), animated: true)
            }
            page.openDay = { [weak self] city, forecast, day in
                guard let self else { return }
                self.navigationController?.pushViewController(ForecastDetailViewController(city: city, forecast: forecast,
                    settings: .load(self.defaults), day: day), animated: true)
            }
            return page
        }
        empty.isHidden = !cities.isEmpty
        dots.numberOfPages = cities.count
        index = min(index, max(0, pages.count - 1))
        if !pages.isEmpty { showPage(index) }
        else { pager.setViewControllers([UIViewController()], direction: .forward, animated: false); title = "Погода"; pageLabel.text = "Нет сохранённых городов" }
    }
    private func showPage(_ newIndex: Int) {
        guard pages.indices.contains(newIndex) else { return }
        pages.indices.filter { $0 != newIndex }.forEach { pages[$0].stop() }
        let direction: UIPageViewController.NavigationDirection = newIndex >= index ? .forward : .reverse
        index = newIndex
        pager.setViewControllers([pages[index]], direction: direction, animated: false)
        updateTitle()
        pages[index].start()
    }
    private func updateTitle() {
        title = cities[index].name
        dots.currentPage = index
        pageLabel.text = "Город \(index + 1) из \(cities.count) · листайте влево и вправо"
        defaults.set(cities[index].id, forKey: "selectedCity")
    }
    @objc private func selectDot() { showPage(dots.currentPage) }
    private func promptCity() {
        guard !busy else { return }
        let alert = UIAlertController(title: "Добавить город", message: "Введите название. Можно уточнить страну через запятую.", preferredStyle: .alert)
        alert.addTextField { field in
            field.placeholder = "Например, Москва"
            field.autocapitalizationType = .words
            field.accessibilityIdentifier = "city-query"
        }
        alert.addAction(UIAlertAction(title: "Отмена", style: .cancel))
        alert.addAction(UIAlertAction(title: "Найти", style: .default) { [weak self, weak alert] _ in
            self?.search(alert?.textFields?.first?.text ?? "")
        })
        present(alert, animated: true)
    }
    private func search(_ query: String) {
        searchTask?.cancel()
        setBusy(true)
        searchTask = Task { [weak self] in
            guard let self else { return }
            defer { self.setBusy(false) }
            do {
                let matches = try await self.geocoding.search(query)
                try Task.checkCancellation()
                if matches.count == 1 { try await self.add(matches[0]) }
                else { self.choose(matches) }
            } catch is CancellationError { }
            catch { self.showError(error.localizedDescription) }
        }
    }
    private func choose(_ cities: [City]) {
        let alert = UIAlertController(title: "Выберите город", message: "Найдено несколько совпадений", preferredStyle: .actionSheet)
        for city in cities {
            alert.addAction(UIAlertAction(title: "\(city.name) · \(city.subtitle)", style: .default) { [weak self] _ in
                guard let self else { return }
                Task { do { try await self.add(city) } catch { self.showError(error.localizedDescription) } }
            })
        }
        alert.addAction(UIAlertAction(title: "Отмена", style: .cancel))
        alert.popoverPresentationController?.barButtonItem = addButton
        present(alert, animated: true)
    }
    private func add(_ city: City) async throws {
        if let existing = cities.firstIndex(where: { $0.matches(city) }) {
            showPage(existing)
            showError("Этот город уже добавлен.")
            return
        }
        let updated = cities + [city]
        try await repository.saveCities(updated)
        cities = updated
        index = cities.count - 1
        rebuild()
    }
    func locate() {
        guard !busy else { return }
        setBusy(true)
        Task {
            defer { setBusy(false) }
            do { try await add(location.locate()) }
            catch { showError("Не удалось определить местоположение. Добавьте город кнопкой «+» или разрешите геопозицию в настройках iOS.\n\(error.localizedDescription)") }
        }
    }
    private func setBusy(_ busy: Bool) {
        self.busy = busy
        addButton.isEnabled = !busy
        if busy { pageLabel.text = "Поиск местоположения…" }
        else if !cities.isEmpty { updateTitle() }
        else { pageLabel.text = "Нет сохранённых городов" }
    }
    private func showSettings() {
        let settings = SettingsViewController(defaults: defaults)
        settings.onSave = { [weak self] in self?.rebuild() }
        settings.onLocation = { [weak self] in self?.locate() }
        settings.onCities = { [weak self] in self?.showCities() }
        present(UINavigationController(rootViewController: settings), animated: true)
    }
    private func showCities() {
        let list = CitiesViewController(cities: cities)
        list.onSelect = { [weak self] index in
            self?.showPage(index)
            self?.navigationController?.popViewController(animated: true)
        }
        list.onDelete = { [weak self] index in
            guard let self else { return }
            var updated = self.cities
            updated.remove(at: index)
            try await self.repository.saveCities(updated)
            self.cities = updated
            self.rebuild()
        }
        navigationController?.pushViewController(list, animated: true)
    }
    private func showError(_ message: String) {
        let alert = UIAlertController(title: "Погода", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Понятно", style: .default))
        present(alert, animated: true)
    }
    func pageViewController(_ pageViewController: UIPageViewController, viewControllerBefore viewController: UIViewController) -> UIViewController? {
        guard let page = viewController as? WeatherViewController, let position = pages.firstIndex(of: page), position > 0 else { return nil }
        return pages[position - 1]
    }
    func pageViewController(_ pageViewController: UIPageViewController, viewControllerAfter viewController: UIViewController) -> UIViewController? {
        guard let page = viewController as? WeatherViewController, let position = pages.firstIndex(of: page), position + 1 < pages.count else { return nil }
        return pages[position + 1]
    }
    func pageViewController(_ pageViewController: UIPageViewController, didFinishAnimating finished: Bool,
                            previousViewControllers: [UIViewController], transitionCompleted completed: Bool) {
        guard completed, let page = pageViewController.viewControllers?.first as? WeatherViewController,
              let position = pages.firstIndex(of: page) else { return }
        previousViewControllers.compactMap { $0 as? WeatherViewController }.forEach { $0.stop() }
        index = position
        updateTitle()
        page.start()
    }
}
