import UIKit

enum Palette {
    static let blue = UIColor(red: 0.13, green: 0.29, blue: 0.77, alpha: 1)
    static let orange = UIColor(red: 0.82, green: 0.26, blue: 0.02, alpha: 1)
    static let accent = UIColor { $0.userInterfaceStyle == .dark
        ? UIColor(red: 0.55, green: 0.72, blue: 1, alpha: 1) : blue }
    static let card = UIColor { $0.userInterfaceStyle == .dark
        ? UIColor(red: 0.12, green: 0.16, blue: 0.27, alpha: 1)
        : UIColor(red: 0.92, green: 0.94, blue: 0.99, alpha: 1) }
}

@MainActor
func label(_ text: String = "", style: UIFont.TextStyle = .body, color: UIColor = .label) -> UILabel {
    let value = UILabel()
    value.text = text
    value.font = .preferredFont(forTextStyle: style)
    value.adjustsFontForContentSizeCategory = true
    value.textColor = color
    value.numberOfLines = 0
    return value
}

@MainActor
func stack(_ views: [UIView], axis: NSLayoutConstraint.Axis = .vertical, spacing: CGFloat = 12) -> UIStackView {
    let value = UIStackView(arrangedSubviews: views)
    value.axis = axis
    value.spacing = spacing
    return value
}

extension UIView {
    func pin(in parent: UIView, inset: CGFloat = 0) {
        translatesAutoresizingMaskIntoConstraints = false
        parent.addSubview(self)
        NSLayoutConstraint.activate([
            leadingAnchor.constraint(equalTo: parent.leadingAnchor, constant: inset),
            trailingAnchor.constraint(equalTo: parent.trailingAnchor, constant: -inset),
            topAnchor.constraint(equalTo: parent.topAnchor, constant: inset),
            bottomAnchor.constraint(equalTo: parent.bottomAnchor, constant: -inset)
        ])
    }
}

@MainActor
func actionButton(_ title: String, id: String, action: @escaping () -> Void) -> UIButton {
    var configuration = UIButton.Configuration.filled()
    configuration.title = title
    configuration.baseBackgroundColor = Palette.orange
    configuration.baseForegroundColor = .white
    configuration.cornerStyle = .large
    configuration.contentInsets = .init(top: 16, leading: 16, bottom: 16, trailing: 16)
    let button = UIButton(configuration: configuration, primaryAction: UIAction { _ in action() })
    button.titleLabel?.adjustsFontForContentSizeCategory = true
    button.titleLabel?.numberOfLines = 0
    button.accessibilityIdentifier = id
    return button
}

final class SunCard: UIView {
    override func draw(_ rect: CGRect) {
        guard !traitCollection.preferredContentSizeCategory.isAccessibilityCategory else { return }
        guard let context = UIGraphicsGetCurrentContext() else { return }
        context.setStrokeColor(UIColor.systemYellow.withAlphaComponent(0.6).cgColor)
        context.setLineWidth(2)
        let path = UIBezierPath()
        path.move(to: CGPoint(x: 18, y: rect.height - 80))
        let controlY = (8 - (rect.height - 80) * 0.25) / 0.75
        path.addCurve(to: CGPoint(x: rect.width - 18, y: rect.height - 80),
                      controlPoint1: CGPoint(x: 18, y: controlY),
                      controlPoint2: CGPoint(x: rect.width - 18, y: controlY))
        path.stroke()
    }
}

final class DailyCell: UITableViewCell {
    static let reuseID = "DailyCell"
    private let dayLabel = label(style: .subheadline)
    private let icon = UIImageView()
    private let condition = label(style: .subheadline)
    private let temperature = label(style: .headline)
    private let probability = label(style: .caption1, color: .secondaryLabel)
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = .clear
        accessoryType = .disclosureIndicator
        icon.tintColor = Palette.accent
        icon.contentMode = .scaleAspectFit
        icon.preferredSymbolConfiguration = .init(pointSize: 25)
        let left = stack([dayLabel, probability], spacing: 5)
        let right = stack([condition, temperature], spacing: 5)
        let row = stack([left, icon, right], axis: .horizontal, spacing: 14)
        row.alignment = .center
        left.widthAnchor.constraint(greaterThanOrEqualToConstant: 65).isActive = true
        icon.widthAnchor.constraint(equalToConstant: 34).isActive = true
        icon.heightAnchor.constraint(equalToConstant: 34).isActive = true
        row.pin(in: contentView, inset: 14)
        contentView.backgroundColor = Palette.card
        contentView.layer.cornerRadius = 10
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    func configure(_ day: DayWeather, zone: String, settings: WeatherSettings, index: Int) {
        dayLabel.text = WeatherFormat.date(day.time, zone: zone, format: "EEE, dd.MM")
        probability.text = "Осадки \(WeatherFormat.number(day.probability, suffix: "%"))"
        icon.image = UIImage(systemName: WeatherCode.symbol(day.code))
        condition.text = WeatherCode.description(day.code)
        temperature.text = "\(settings.temperature(day.low)) … \(settings.temperature(day.high))"
        accessibilityIdentifier = "day-\(index)"
    }
}

final class HourCell: UICollectionViewCell {
    static let reuseID = "HourCell"
    let time = label(style: .caption1, color: .secondaryLabel)
    let icon = UIImageView()
    let temperature = label(style: .headline)
    let probability = label(style: .caption2, color: .secondaryLabel)
    override init(frame: CGRect) {
        super.init(frame: frame)
        contentView.backgroundColor = Palette.card
        contentView.layer.cornerRadius = 25
        icon.contentMode = .scaleAspectFit
        icon.tintColor = Palette.accent
        let column = stack([time, icon, temperature, probability], spacing: 6)
        column.alignment = .center
        column.pin(in: contentView, inset: 10)
        icon.heightAnchor.constraint(equalToConstant: 28).isActive = true
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}

final class HourStrip: UIView, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    private let collection: UICollectionView
    private var hours: [HourWeather] = []
    private var zone = "GMT"
    private var settings = WeatherSettings()
    private var selectedIndex: Int?
    var onSelect: ((Int) -> Void)?
    init() {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .horizontal
        layout.minimumLineSpacing = 10
        collection = UICollectionView(frame: .zero, collectionViewLayout: layout)
        super.init(frame: .zero)
        collection.backgroundColor = .clear
        collection.showsHorizontalScrollIndicator = false
        collection.accessibilityIdentifier = "hour-strip"
        collection.register(HourCell.self, forCellWithReuseIdentifier: HourCell.reuseID)
        collection.dataSource = self
        collection.delegate = self
        collection.pin(in: self)
        heightAnchor.constraint(equalToConstant: UIFontMetrics.default.scaledValue(for: 112)).isActive = true
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    func configure(hours: [HourWeather], zone: String, settings: WeatherSettings, selected: Int? = nil) {
        self.hours = hours
        self.zone = zone
        self.settings = settings
        selectedIndex = selected
        collection.reloadData()
    }
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int { hours.count }
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: HourCell.reuseID, for: indexPath) as! HourCell
        let hour = hours[indexPath.item]
        cell.time.text = settings.time(hour.time, zone: zone)
        cell.icon.image = UIImage(systemName: WeatherCode.symbol(hour.code, isDay: hour.isDay))
        cell.temperature.text = settings.temperature(hour.temperature)
        cell.probability.text = WeatherFormat.number(hour.probability, suffix: "%")
        let selected = indexPath.item == selectedIndex
        cell.contentView.backgroundColor = selected ? Palette.blue : Palette.card
        cell.time.textColor = selected ? .white : .secondaryLabel
        cell.temperature.textColor = selected ? .white : .label
        cell.probability.textColor = selected ? .white : .secondaryLabel
        cell.icon.tintColor = selected ? .systemYellow : Palette.accent
        cell.isAccessibilityElement = true
        cell.accessibilityLabel = "\(settings.time(hour.time, zone: zone)), \(WeatherCode.description(hour.code)), \(settings.temperature(hour.temperature)), вероятность осадков \(WeatherFormat.number(hour.probability, suffix: "%"))"
        cell.accessibilityTraits = selected ? [.button, .selected] : [.button]
        cell.accessibilityIdentifier = "hour-\(indexPath.item)"
        return cell
    }
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        selectedIndex = indexPath.item
        collectionView.reloadData()
        onSelect?(indexPath.item)
    }
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout,
                        sizeForItemAt indexPath: IndexPath) -> CGSize {
        CGSize(width: UIFontMetrics.default.scaledValue(for: settings.twelveHour ? 104 : 80), height: bounds.height)
    }
}
