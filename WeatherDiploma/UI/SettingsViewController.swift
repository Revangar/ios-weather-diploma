import UIKit
import UserNotifications

final class SettingsViewController: UITableViewController {
    private let defaults: UserDefaults
    private var settings: WeatherSettings
    var onSave: (() -> Void)?
    var onLocation: (() -> Void)?
    var onCities: (() -> Void)?
    init(defaults: UserDefaults) {
        self.defaults = defaults
        settings = .load(defaults)
        super.init(style: .insetGrouped)
        title = "Настройки"
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = Palette.blue
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "setting")
        tableView.register(AccessibleSettingCell.self, forCellReuseIdentifier: "accessible-setting")
        registerForTraitChanges([UITraitPreferredContentSizeCategory.self]) { (controller: SettingsViewController, _: UITraitCollection) in
            controller.tableView.reloadData()
        }
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = Palette.blue
        appearance.titleTextAttributes = [.foregroundColor: UIColor.white]
        navigationItem.standardAppearance = appearance
        navigationItem.scrollEdgeAppearance = appearance
        navigationItem.rightBarButtonItem = UIBarButtonItem(customView: actionButton("Установить", id: "apply-settings") { [weak self] in
            guard let self else { return }
            self.settings.save(self.defaults)
            self.onSave?()
            self.dismiss(animated: true)
        })
    }
    override func numberOfSections(in tableView: UITableView) -> Int { 3 }
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { [4, 2, 2][section] }
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        ["Единицы и время", "Города", "Об источниках"][section]
    }
    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        switch section {
        case 0: "Уведомление — ежедневное напоминание в 08:00 по времени устройства. Прогноз в фоне не загружается. Единицы и формат времени применяются кнопкой «Установить»."
        case 2: "Учебное некоммерческое приложение. Геопозиция передаётся погодному сервису только при вашем запросе. Города и полный прогноз хранятся локально. Режим на 25 дней недоступен."
        default: nil
        }
    }
    override func tableView(_ tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int) {
        (view as? UITableViewHeaderFooterView)?.textLabel?.textColor = .white
    }
    override func tableView(_ tableView: UITableView, willDisplayFooterView view: UIView, forSection section: Int) {
        (view as? UITableViewHeaderFooterView)?.textLabel?.textColor = .white
    }
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "setting", for: indexPath)
        cell.accessoryView = nil
        cell.accessoryType = .none
        cell.backgroundColor = Palette.card
        var config = cell.defaultContentConfiguration()
        config.textProperties.numberOfLines = 0
        if indexPath.section == 0 {
            config.text = ["Температура", "Скорость ветра", "Формат времени", "Напоминание"][indexPath.row]
            if indexPath.row < 3 {
                let controls = [["°C", "°F"], ["м/с", "миль/ч"], ["24", "12"]]
                let control = UISegmentedControl(items: controls[indexPath.row])
                control.selectedSegmentIndex = [settings.fahrenheit, settings.miles, settings.twelveHour][indexPath.row] ? 1 : 0
                control.accessibilityIdentifier = ["setting-temperature", "setting-wind", "setting-time"][indexPath.row]
                control.addAction(UIAction { [weak self, weak control] _ in
                    guard let self else { return }
                    let selected = control?.selectedSegmentIndex == 1
                    switch indexPath.row {
                    case 0: self.settings.fahrenheit = selected
                    case 1: self.settings.miles = selected
                    default: self.settings.twelveHour = selected
                    }
                }, for: .valueChanged)
                cell.accessoryView = control
            } else {
                let toggle = UISwitch()
                toggle.isOn = defaults.bool(forKey: "reminder")
                toggle.accessibilityIdentifier = "setting-reminder"
                toggle.addAction(UIAction { [weak self, weak toggle] _ in
                    guard let self, let toggle else { return }
                    Task { await self.updateReminder(toggle) }
                }, for: .valueChanged)
                cell.accessoryView = toggle
            }
        } else if indexPath.section == 1 {
            config.text = indexPath.row == 0 ? "Мои города" : "Моё местоположение"
            cell.accessoryType = .disclosureIndicator
        } else {
            config.text = indexPath.row == 0 ? "Open-Meteo · CC BY 4.0" : "Геокодинг · GeoNames"
            cell.accessoryType = .disclosureIndicator
        }
        if traitCollection.preferredContentSizeCategory.isAccessibilityCategory,
           let control = cell.accessoryView as? UISegmentedControl {
            cell.accessoryView = nil
            let accessible = tableView.dequeueReusableCell(withIdentifier: "accessible-setting", for: indexPath) as! AccessibleSettingCell
            accessible.configure(title: config.text ?? "", control: control)
            return accessible
        }
        cell.contentConfiguration = config
        return cell
    }
    private func updateReminder(_ toggle: UISwitch) async {
        let center = UNUserNotificationCenter.current()
        if !toggle.isOn {
            center.removePendingNotificationRequests(withIdentifiers: ["weather-reminder"])
            defaults.set(false, forKey: "reminder")
            return
        }
        do {
            guard try await center.requestAuthorization(options: [.alert, .sound]) else {
                toggle.isOn = false
                defaults.set(false, forKey: "reminder")
                showError("Разрешите уведомления в настройках iOS.")
                return
            }
            let content = UNMutableNotificationContent()
            content.title = "Погода на сегодня"
            content.body = "Откройте приложение, чтобы обновить прогноз для ваших городов."
            content.sound = .default
            let trigger = UNCalendarNotificationTrigger(dateMatching: DateComponents(hour: 8), repeats: true)
            try await center.add(UNNotificationRequest(identifier: "weather-reminder", content: content, trigger: trigger))
            defaults.set(true, forKey: "reminder")
        } catch { toggle.isOn = false; defaults.set(false, forKey: "reminder"); showError(error.localizedDescription) }
    }
    private func showError(_ message: String) {
        let alert = UIAlertController(title: "Уведомления", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Понятно", style: .default))
        present(alert, animated: true)
    }
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        if indexPath.section == 1 {
            let action = indexPath.row == 0 ? onCities : onLocation
            dismiss(animated: true) { action?() }
        } else if indexPath.section == 2 {
            UIApplication.shared.open(URL(string: indexPath.row == 0 ? "https://open-meteo.com/" : "https://www.geonames.org/")!)
        }
    }
}

/// Gives large-text users readable segment titles without squeezing the setting name.
private final class AccessibleSettingCell: UITableViewCell {
    private let title = label()
    private let column = stack([], spacing: 12)
    private var control: UISegmentedControl?
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        selectionStyle = .none
        backgroundColor = Palette.card
        column.addArrangedSubview(title)
        column.pin(in: contentView, inset: 16)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    func configure(title: String, control: UISegmentedControl) {
        self.title.text = title
        self.control?.removeFromSuperview()
        self.control = control
        control.apportionsSegmentWidthsByContent = true
        let font = UIFont.preferredFont(forTextStyle: .body)
        control.setTitleTextAttributes([.font: font], for: .normal)
        control.setTitleTextAttributes([.font: font], for: .selected)
        control.heightAnchor.constraint(greaterThanOrEqualToConstant: font.lineHeight + 16).isActive = true
        column.addArrangedSubview(control)
    }
}

final class CitiesViewController: UITableViewController {
    var cities: [City]
    var onDelete: ((Int) async throws -> Void)?
    var onSelect: ((Int) -> Void)?
    init(cities: [City]) { self.cities = cities; super.init(style: .insetGrouped); title = "Мои города" }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    override func viewDidLoad() { super.viewDidLoad(); tableView.register(UITableViewCell.self, forCellReuseIdentifier: "city") }
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { cities.count }
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "city", for: indexPath)
        var config = cell.defaultContentConfiguration()
        config.text = cities[indexPath.row].name
        config.secondaryText = cities[indexPath.row].subtitle
        cell.contentConfiguration = config
        return cell
    }
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) { onSelect?(indexPath.row) }
    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        guard editingStyle == .delete else { return }
        tableView.isUserInteractionEnabled = false
        Task {
            defer { tableView.isUserInteractionEnabled = true }
            do {
                try await onDelete?(indexPath.row)
                cities.remove(at: indexPath.row)
                tableView.deleteRows(at: [indexPath], with: .automatic)
            } catch {
                let alert = UIAlertController(title: "Не удалось удалить город", message: error.localizedDescription, preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "Понятно", style: .default))
                present(alert, animated: true)
            }
        }
    }
}
