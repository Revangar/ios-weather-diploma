import UIKit

/// Keeps text and forecast cards readable on iPad while preserving the full iPhone safe area.
final class ReadableContainerViewController: UIViewController {
    private let content: UIViewController
    init(_ content: UIViewController) {
        self.content = content
        super.init(nibName: nil, bundle: nil)
        title = content.title
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemGroupedBackground
        addChild(content)
        content.view.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(content.view)
        content.didMove(toParent: self)
        let fillWidth = content.view.widthAnchor.constraint(equalTo: view.safeAreaLayoutGuide.widthAnchor)
        fillWidth.priority = .defaultHigh
        NSLayoutConstraint.activate([
            content.view.centerXAnchor.constraint(equalTo: view.safeAreaLayoutGuide.centerXAnchor),
            content.view.widthAnchor.constraint(lessThanOrEqualTo: view.safeAreaLayoutGuide.widthAnchor),
            content.view.widthAnchor.constraint(lessThanOrEqualToConstant: 760), fillWidth,
            content.view.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            content.view.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor)
        ])
    }
}
