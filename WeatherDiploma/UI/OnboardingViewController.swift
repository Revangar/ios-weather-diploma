import UIKit

final class OnboardingViewController: UIViewController {
    var onFinish: ((Bool) -> Void)?
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = Palette.blue
        let scroll = UIScrollView()
        scroll.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scroll)
        NSLayoutConstraint.activate([
            scroll.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
            scroll.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scroll.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor)
        ])
        let icon = UIImageView(image: UIImage(systemName: "umbrella.fill"))
        icon.tintColor = .systemYellow
        icon.contentMode = .scaleAspectFit
        icon.heightAnchor.constraint(equalToConstant: 190).isActive = true
        let title = label("Погода там,\nгде вы", style: .largeTitle, color: .white)
        let text = label("Разрешите доступ к геопозиции, чтобы увидеть прогноз рядом с вами. Координаты передаются Open-Meteo только для получения погоды.", color: .white)
        let note = label("Можно обойтись без геопозиции и добавить любой город вручную. Разрешение меняется в настройках iOS.", style: .subheadline, color: .white)
        let allow = actionButton("Использовать местоположение", id: "onboarding-location") { [weak self] in self?.onFinish?(true) }
        let skip = UIButton(type: .system)
        skip.setTitle("Добавлю город вручную", for: .normal)
        skip.setTitleColor(.white, for: .normal)
        skip.titleLabel?.font = .preferredFont(forTextStyle: .headline)
        skip.titleLabel?.numberOfLines = 0
        skip.accessibilityIdentifier = "onboarding-skip"
        skip.addAction(UIAction { [weak self] _ in self?.onFinish?(false) }, for: .touchUpInside)
        let column = stack([icon, title, text, note, allow, skip], spacing: 24)
        column.translatesAutoresizingMaskIntoConstraints = false
        scroll.addSubview(column)
        NSLayoutConstraint.activate([
            column.leadingAnchor.constraint(equalTo: scroll.contentLayoutGuide.leadingAnchor, constant: 28),
            column.trailingAnchor.constraint(equalTo: scroll.contentLayoutGuide.trailingAnchor, constant: -28),
            column.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor, constant: 30),
            column.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor, constant: -30),
            column.widthAnchor.constraint(equalTo: scroll.frameLayoutGuide.widthAnchor, constant: -56)
        ])
    }
}
