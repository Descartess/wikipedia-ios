import Foundation

@objc(WMFReadingListsViewController)
class ReadingListsViewController: ColumnarCollectionViewController {
    
    let dataStore: MWKDataStore
    let managedObjectContext: NSManagedObjectContext
    let readingListsController: ReadingListsController
    var fetchedResultsController: NSFetchedResultsController<ReadingList>!
    var collectionViewUpdater: CollectionViewUpdater<ReadingList>!
    var cellLayoutEstimate: WMFLayoutEstimate?
    var editController: CollectionViewEditController!
    fileprivate var articles: [WMFArticle] = []
    
    fileprivate let reuseIdentifier = "ReadingListsViewControllerCell"
    
    fileprivate var isList: Bool = false
    public weak var addArticlesToReadingListDelegate: AddArticlesToReadingListDelegate?

    func setupFetchedResultsControllerOrdered(by key: String, ascending: Bool) {
        let request: NSFetchRequest<ReadingList> = ReadingList.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: key, ascending: ascending)]
        fetchedResultsController = NSFetchedResultsController(fetchRequest: request, managedObjectContext: managedObjectContext, sectionNameKeyPath: nil, cacheName: nil)
        do {
            try fetchedResultsController.performFetch()
        } catch let error {
            DDLogError("Error fetching reading lists: \(error)")
        }
        collectionView.reloadData()
    }
    
    init(with dataStore: MWKDataStore) {
        self.dataStore = dataStore
        self.managedObjectContext = dataStore.viewContext
        self.readingListsController = dataStore.readingListsController
        super.init()
    }
    
    convenience init(with dataStore: MWKDataStore, articles: [WMFArticle]) {
        self.init(with: dataStore)
        self.articles = articles
        self.isList = true
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) not supported")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupFetchedResultsControllerOrdered(by: "name", ascending: true)
        collectionViewUpdater = CollectionViewUpdater(fetchedResultsController: fetchedResultsController, collectionView: collectionView)
        collectionViewUpdater?.delegate = self

        register(SavedCollectionViewCell.self, forCellWithReuseIdentifier: reuseIdentifier, addPlaceholder: true)
        
        editController = CollectionViewEditController(collectionView: collectionView)
        editController.delegate = self
        // Remove peek & pop for now
        unregisterForPreviewing()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        updateEmptyState()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        editController.close()
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        cellLayoutEstimate = nil
    }
    
    func readingList(at indexPath: IndexPath) -> ReadingList? {
        guard let sections = fetchedResultsController.sections,
            indexPath.section < sections.count,
            indexPath.item < sections[indexPath.section].numberOfObjects else {
                return nil
        }
        return fetchedResultsController.object(at: indexPath)
    }
    
    @objc func presentCreateReadingListViewController() {
        let createReadingListViewController = CreateReadingListViewController(theme: self.theme)
        createReadingListViewController.delegate = self
        present(createReadingListViewController, animated: true, completion: nil)
    }
    
    open func configure(cell: SavedCollectionViewCell, forItemAt indexPath: IndexPath, layoutOnly: Bool) {
        guard let readingList = readingList(at: indexPath) else {
            return
        }
        
        cell.actions = availableActions(at: indexPath)
        cell.isBatchEditable = true
        let numberOfItems = self.collectionView(collectionView, numberOfItemsInSection: indexPath.section)
        cell.configure(readingList: readingList, index: indexPath.item, count: numberOfItems, shouldAdjustMargins: false, shouldShowSeparators: true, theme: theme)
        cell.layoutMargins = layout.readableMargins
        
        guard let translation = editController.swipeTranslationForItem(at: indexPath) else {
            return
        }
        cell.swipeTranslation = translation
    }
    
    // MARK: - Empty state
    
    fileprivate var isEmpty = true {
        didSet {
            editController.isCollectionViewEmpty = isEmpty
        }
    }
    
    fileprivate final func updateEmptyState() {
        let sectionCount = numberOfSections(in: collectionView)
        
        isEmpty = true
        for sectionIndex in 0..<sectionCount {
            if self.collectionView(collectionView, numberOfItemsInSection: sectionIndex) > 0 {
                isEmpty = false
                break
            }
        }
        if isEmpty {
            wmf_showEmptyView(of: WMFEmptyViewType.noReadingLists, theme: theme)
        } else {
            wmf_hideEmptyView()
        }
    }
    
    // MARK: - Batch editing
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard !isList else {
            guard let selectedReadingList = readingList(at: indexPath) else {
                return
            }
            do {
                try readingListsController.add(articles: articles, to: selectedReadingList)
                addArticlesToReadingListDelegate?.addedArticleToReadingList?(named: selectedReadingList.name!)
            } catch let err {
                print(err)
                // do something
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(200)) {
                self.dismiss(animated: true, completion: nil)
            }
            return
        }
        
        guard editController.batchEditingState != .open else {
            editController.didTapCellWhileBatchEditing()
            return
        }
        guard let readingList = readingList(at: indexPath) else {
            return
        }
        let readingListDetailViewController = ReadingListDetailViewController(for: readingList, with: dataStore)
        readingListDetailViewController.apply(theme: theme)
        wmf_push(readingListDetailViewController, animated: true)
    }
    
    func collectionView(_ collectionView: UICollectionView, didDeselectItemAt indexPath: IndexPath) {
        if editController.batchEditingState == .open {
            editController.didTapCellWhileBatchEditing()
        }
    }
    
    lazy var availableBatchEditToolbarActions: [BatchEditToolbarAction] = {
        let updateItem = BatchEditToolbarActionType.update.action(with: self)
        let deleteItem = BatchEditToolbarActionType.delete.action(with: self)
        return [updateItem, deleteItem]
    }()
    
}

// MARK: - CreateReadingListViewControllerDelegate

extension ReadingListsViewController: CreateReadingListDelegate {
    func createdNewReadingList(in controller: CreateReadingListViewController, with name: String, description: String?) {
        do {
            let _ = try readingListsController.createReadingList(named: name, description: description)
            controller.dismiss(animated: true, completion: nil)
        } catch let err {
            print(err)
            // show error
        }
    }
}

// MARK: - UICollectionViewDataSource
extension ReadingListsViewController {
    override func numberOfSections(in collectionView: UICollectionView) -> Int {
        guard let sectionsCount = self.fetchedResultsController.sections?.count else {
            return 0
        }
        return sectionsCount
    }
    
    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        guard let sections = self.fetchedResultsController.sections, section < sections.count else {
            return 0
        }
        return sections[section].numberOfObjects
    }
    
    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: reuseIdentifier, for: indexPath)
        guard let readingListCell = cell as? SavedCollectionViewCell else {
            return cell
        }
        configure(cell: readingListCell, forItemAt: indexPath, layoutOnly: false)
        return cell
    }
}

// MARK: - CollectionViewUpdaterDelegate
extension ReadingListsViewController: CollectionViewUpdaterDelegate {
    func collectionViewUpdater<T>(_ updater: CollectionViewUpdater<T>, didUpdate collectionView: UICollectionView) {
        for indexPath in collectionView.indexPathsForVisibleItems {
            guard let cell = collectionView.cellForItem(at: indexPath) as? SavedCollectionViewCell else {
                continue
            }
            cell.configureSeparators(for: indexPath.item)
            cell.actions = availableActions(at: indexPath)
        }
        updateEmptyState()
        collectionView.setNeedsLayout()
    }
    
}

// MARK: - ActionDelegate
extension ReadingListsViewController: ActionDelegate {
    
    func didPerformBatchEditToolbarAction(_ action: BatchEditToolbarAction) -> Bool {
        guard let selectedIndexPaths = collectionView.indexPathsForSelectedItems else {
            return false
        }
        
        let readingLists: [ReadingList] = selectedIndexPaths.flatMap({ readingList(at: $0) })
        let articlesCount = readingLists.flatMap({ $0.entries?.count }).reduce( 0, + )
        
        func delete(_ readingLists: [ReadingList]) -> Bool {
            do {
                try self.readingListsController.delete(readingLists: readingLists)
                return true
            } catch let err {
                print(err)
            }
            return false
        }
        
        switch action.type {
        case .update:
            print("Update")
            return true
        case .delete:
            let title = "Delete reading lists and all of their saved articles?"
            let message = "Your \(readingLists.count) lists and \(articlesCount) articles will be deleted"
            let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
            let cancelAction = UIAlertAction(title: "Cancel", style: .cancel, handler: { (action) in
                alert.dismiss(animated: true, completion: nil)
            })
            var didPerform = false
            let deleteAction = UIAlertAction(title: "Delete", style: .destructive, handler: { (action) in
                do {
                    try self.readingListsController.delete(readingLists: readingLists)
                } catch let err {
                    print(err)
                }
            })
            alert.addAction(cancelAction)
            alert.addAction(deleteAction)
            present(alert, animated: true, completion: {
                didPerform = true
            })
            return didPerform
        default:
            break
        }
        return false
    }
    
    func didPerformAction(_ action: Action) -> Bool {
        let indexPath = action.indexPath
        guard let readingList = readingList(at: indexPath) else {
            return false
        }
        switch action.type {
        case .delete:
            do {
            try readingListsController.delete(readingLists: [readingList])
            } catch let err {
                print(err)
                // do something
            }
            UIAccessibilityPostNotification(UIAccessibilityAnnouncementNotification, WMFLocalizedString("reading-list-deleted-accessibility-notification", value: "Reading list deleted", comment: "Notification spoken after user deletes a reading list from the list."))
            return true
        default:
            return false
        }
    }
    
    func availableActions(at indexPath: IndexPath) -> [Action] {
        return [ActionType.delete.action(with: self, indexPath: indexPath)]
    }

}

// MARK: - WMFColumnarCollectionViewLayoutDelegate
extension ReadingListsViewController {
    override func collectionView(_ collectionView: UICollectionView, estimatedHeightForItemAt indexPath: IndexPath, forColumnWidth columnWidth: CGFloat) -> WMFLayoutEstimate {
        // The layout estimate can be re-used in this case becuause both labels are one line, meaning the cell
        // size only varies with font size. The layout estimate is nil'd when the font size changes on trait collection change
        if let estimate = cellLayoutEstimate {
            return estimate
        }
        var estimate = WMFLayoutEstimate(precalculated: false, height: 60)
        guard let placeholderCell = placeholder(forCellWithReuseIdentifier: reuseIdentifier) as? SavedCollectionViewCell else {
            return estimate
        }
        placeholderCell.prepareForReuse()
        configure(cell: placeholderCell, forItemAt: indexPath, layoutOnly: true)
        estimate.height = placeholderCell.sizeThatFits(CGSize(width: columnWidth, height: UIViewNoIntrinsicMetric), apply: false).height
        estimate.precalculated = true
        cellLayoutEstimate = estimate
        return estimate
    }
    
    override func metrics(withBoundsSize size: CGSize, readableWidth: CGFloat) -> WMFCVLMetrics {
        return WMFCVLMetrics.singleColumnMetrics(withBoundsSize: size, readableWidth: readableWidth,  collapseSectionSpacing:true)
    }
}
