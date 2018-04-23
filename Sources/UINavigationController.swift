open class UINavigationController: UIViewController {
    /// Note: not currently implemented!
    open var modalPresentationStyle: UIModalPresentationStyle = .formSheet

    public init(rootViewController: UIViewController) {
        super.init(nibName: nil, bundle: nil)
        pushViewController(rootViewController, animated: false)
        updateNavigationBarItems()
    }

    open override func loadView() {
        view = UINavigationControllerContainerView()
        view.addSubview(transitionView)
        view.addSubview(navigationBar)
    }

    open internal(set) var navigationBar = UINavigationBar()
    internal var transitionView = UIView() // animates the other views on push/pop

    open internal(set) var viewControllers: [UIViewController] = [] {
        didSet { updateNavigationBarItems() }
    }

    private func updateNavigationBarItems() {
        navigationBar.items = viewControllers.map { $0.navigationItem }
    }

    private func updateUIFromViewControllerStack(animated: Bool) {
        guard let view = _view else { return }

        transitionView.subviews.forEach { $0.removeFromSuperview() }

        if let viewOnTopOfStack = viewControllers.last?.view {
            // TODO: Animate here
            viewOnTopOfStack.frame = transitionView.bounds
            transitionView.addSubview(viewOnTopOfStack)
        }
    }

    open func pushViewController(_ otherViewController: UIViewController, animated: Bool) {
        otherViewController.navigationController = self
        viewControllers.append(otherViewController)
        updateUIFromViewControllerStack(animated: animated)
    }

    open func popViewController(animated: Bool) -> UIViewController? {
        // You can't pop the rootViewController (per iOS docs)
        if viewControllers.count <= 1 { return nil }

        let topOfStack = viewControllers.popLast()!
        topOfStack.dismiss(animated: false) // XXX: not sure if this is correct.
        updateUIFromViewControllerStack(animated: animated)
        return topOfStack
    }

    open override func dismiss(animated: Bool, completion: (() -> Void)?) {
        let topOfStack = viewControllers.last
        topOfStack?.viewWillDisappear()

        // XXX: without the following line it's impossible to present the
        // `topOfStack` viewController again - you just get a blank screen.
        // Although it's correct to have this line here, it's creepy that it breaks
        // without it. We should investigate a possible memory leak or logic error.
        topOfStack?.view?.removeFromSuperview()

        topOfStack?.viewDidDisappear()
        super.dismiss(animated: animated, completion: completion)
    }

    open override func viewWillAppear(_ animated: Bool) {
        if viewControllers.isEmpty {
            preconditionFailure(
                "A UINavigationController must contain at least one other view controller when it is presented")
        }

        super.viewWillAppear(animated)
        navigationBar.frame = view.bounds
        navigationBar.frame.size.height = 40
        navigationBar.backgroundColor = .lightGray

        transitionView.frame = view.bounds

        // This `animated` bool is unrelated to the one passed into viewWillAppear:
        updateUIFromViewControllerStack(animated: false)
    }
}
