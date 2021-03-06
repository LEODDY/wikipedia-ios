import Foundation

public enum CollectionViewCellSwipeType {
    case primary, secondary, none
}

enum CollectionViewCellState {
    case idle, open
}

public class CollectionViewSwipeToEditController: NSObject, UIGestureRecognizerDelegate, ActionsViewDelegate {
    
    let collectionView: UICollectionView
    
    var currentState: CollectionViewCellState = .idle {
        didSet {
            currentState == .idle ? didEnterIdleState() : didEnterOpenState()
        }
    }
    
    var activeCell: ArticleCollectionViewCell?
    var activeIndexPath: IndexPath?
    var activeDirectionIsPrimary: Bool?
    
    public var primaryActions: [CollectionViewCellAction] = []
    public var secondaryActions: [CollectionViewCellAction] = []
    
    
    public init(collectionView: UICollectionView) {
        self.collectionView = collectionView
        super.init()
        
        let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePanGesture))
        let longPress = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPressGesture))


        if let gestureRecognizers = self.collectionView.gestureRecognizers {
            var otherGestureRecognizer: UIGestureRecognizer
            for gestureRecognizer in gestureRecognizers {
                otherGestureRecognizer = gestureRecognizer is UIPanGestureRecognizer ? pan : longPress
                gestureRecognizer.require(toFail: otherGestureRecognizer)
            }

        }
        
        pan.delegate = self
        self.collectionView.addGestureRecognizer(pan)
        
        longPress.delegate = self
        longPress.minimumPressDuration = 0.05
        self.collectionView.addGestureRecognizer(longPress)
        
    }
    
    public func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        if let pan = gestureRecognizer as? UIPanGestureRecognizer {
            return panGestureRecognizerShouldBegin(pan)
        }
        
        if let longPress = gestureRecognizer as? UILongPressGestureRecognizer {
            return longPressGestureRecognizerShouldBegin(longPress)
        }
        
        return false
    }
    
    public weak var delegate: CollectionViewSwipeToEditDelegate?
    
    public func didPerformAction(_ action: CollectionViewCellAction) {
        guard let indexPath = activeIndexPath else {
            return
        }
        delegate?.didPerformAction(action, at: indexPath)
    }
    
    func panGestureRecognizerShouldBegin(_ gestureRecognizer: UIPanGestureRecognizer) -> Bool {
        guard let delegate = delegate else {
            return false
        }
        
        let position = gestureRecognizer.location(in: collectionView)
        
        guard let indexPath = collectionView.indexPathForItem(at: position),
            let cell = collectionView.cellForItem(at: indexPath) as? ArticleCollectionViewCell else {
                return false
        }

        let velocity = gestureRecognizer.velocity(in: collectionView)
        
        // Begin only if there's enough x velocity.
        if fabs(velocity.y) >= fabs(velocity.x) {
            return false
        }
        
        let isPrimary = velocity.x < 0
        
        if indexPath == activeIndexPath && isPrimary != activeDirectionIsPrimary {
            return true
        }
        
        if activeIndexPath != nil && activeIndexPath != indexPath {
            return false
        }
        
        guard activeIndexPath == nil else {
            return true
        }
        
        let primaryActions = delegate.primaryActions(for: indexPath)
        let secondaryActions = delegate.secondaryActions(for: indexPath)
        
        let actions = isPrimary ? primaryActions : secondaryActions
        
        guard actions.count > 0 else {
            return false
        }
        
        cell.actions = actions
        cell.actionsView?.delegate = self
        
        activeDirectionIsPrimary = isPrimary
        activeCell = cell
        activeIndexPath = indexPath
        
        cell.swipeType = isPrimary ? .primary : .secondary
        
        return true
    }
    
    func longPressGestureRecognizerShouldBegin(_ gestureRecognizer: UILongPressGestureRecognizer) -> Bool {
        guard let cell = activeCell else {
            return false
        }
        
        // Don't allow the cancel gesture to recognize if any of the touches are within the actions view.
        let numberOfTouches = gestureRecognizer.numberOfTouches
        
        for touchIndex in 0..<numberOfTouches {
            let touchLocation = gestureRecognizer.location(ofTouch: touchIndex, in: cell)
            let touchedActionsView = cell.actionsViewRect.contains(touchLocation)
            return !touchedActionsView
        }
        
        return true
    }
    
    public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        
        if gestureRecognizer is UILongPressGestureRecognizer {
            return true
        }
        
        if gestureRecognizer is UIPanGestureRecognizer{
            return otherGestureRecognizer is UILongPressGestureRecognizer
        }
        
        return false
    }
    
    @objc func handlePanGesture(_ sender: UIPanGestureRecognizer) {
        guard let cell = activeCell else {
            return
        }
        
        switch (sender.state) {
        case .began:
            let position = sender.location(in: cell)
            let velocityX = sender.velocity(in: cell).x
            cell.beginSwipe(with: position, velocity: velocityX)
            currentState = .open
        case .changed:
            let position = sender.location(in: cell)
            let velocityX = sender.velocity(in: cell).x
            cell.updateSwipe(with: position, velocity: velocityX)
        case .cancelled:
            currentState = .idle
        default:
            break
        }
    }
    
    @objc func handleLongPressGesture(_ sender: UILongPressGestureRecognizer) {
        guard activeCell != nil else {
            return
        }
        
        switch (sender.state) {
        case .ended:
            currentState = .idle
            sender.isEnabled = false
            sender.isEnabled = true
        default:
            break
        }
    }
    
    // MARK: - States
    func didEnterIdleState() {
        collectionView.isScrollEnabled = true
        guard let cell = activeCell else {
            return
        }
        cell.closeActionPane()
        activeCell = nil
        activeIndexPath = nil
        activeDirectionIsPrimary = nil
    }
    
    func didEnterOpenState() {
        collectionView.isScrollEnabled = false
        guard let cell = activeCell else {
            return
        }
        cell.openActionPane()
    }
    
    public func performedAction() {
        closeActionPane()
    }
    
    func closeActionPane() {
        currentState = .idle
    }
    
}
