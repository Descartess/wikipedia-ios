import UIKit

protocol CreateReadingListDelegate: NSObjectProtocol {
    func createReadingListViewController(_ createReadingListViewController: CreateReadingListViewController, didCreateReadingListWith name: String, description: String?, articles: [WMFArticle])
}

class CreateReadingListViewController: WMFScrollViewController, UITextFieldDelegate {
        
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var readingListNameLabel: UILabel!
    @IBOutlet weak var descriptionLabel: UILabel!
    @IBOutlet weak var readingListNameErrorLabel: UILabel!
    @IBOutlet weak var readingListNameTextField: ThemeableTextField!
    @IBOutlet weak var descriptionTextField: ThemeableTextField!
    
    @IBOutlet weak var createReadingListButton: WMFAuthButton!
    
    fileprivate var theme: Theme = Theme.standard
    fileprivate let articles: [WMFArticle]
    public let moveFromReadingList: ReadingList?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        apply(theme: theme)
        readingListNameTextField.delegate = self
        descriptionTextField.delegate = self
        readingListNameTextField.returnKeyType = .next
        readingListNameTextField.enablesReturnKeyAutomatically = true
        
        readingListNameTextField.placeholder = WMFLocalizedString("reading-list-new-list-name-placeholder", value: "reading list title", comment: "Placeholder text appearing in text field for entering new list name")
        descriptionTextField.placeholder = WMFLocalizedString("reading-list-new-list-description-placeholder", value: "optional short description", comment: "Placeholder text appearing in text field for entering new list description")
        
        createReadingListButton.isEnabled = false
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        view.endEditing(false)
    }
    
    @objc func closeButtonPressed() {
        dismiss(animated: true, completion: nil)
    }
    
    init(theme: Theme, articles: [WMFArticle], moveFromReadingList: ReadingList? = nil) {
        self.theme = theme
        self.articles = articles
        self.moveFromReadingList = moveFromReadingList
        super.init(nibName: "CreateReadingListViewController", bundle: nil)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    weak var delegate: CreateReadingListDelegate?
    
    @IBAction func createReadingListButtonPressed() {
        guard !isReadingListNameFieldEmpty, let trimmedName = readingListNameTextField.text?.trimmingCharacters(in: .whitespaces) else {
            return
        }
        let trimmedDescription = descriptionTextField.text?.trimmingCharacters(in: .whitespaces)
        delegate?.createReadingListViewController(self, didCreateReadingListWith: trimmedName, description: trimmedDescription, articles: articles)
    }
    
    func handleReadingListNameError(_ error: ReadingListError) {
        readingListNameTextField.textColor = theme.colors.error
        readingListNameErrorLabel.isHidden = false
        readingListNameErrorLabel.text = error.localizedDescription
        createReadingListButton.isEnabled = false
    }
    
    private func hideReadingListError() {
        guard !readingListNameErrorLabel.isHidden else {
            return
        }
        readingListNameErrorLabel.isHidden = true
        readingListNameTextField.textColor = theme.colors.primaryText
    }
    
    private var shouldEnableCreateReadingListButton: Bool {
        return (!isReadingListNameFieldEmpty && readingListNameTextField.isFirstResponder) && readingListNameErrorLabel.isHidden
    }
    
    // MARK: - UITextFieldDelegate
    
    fileprivate var isReadingListNameFieldEmpty: Bool {
        return !readingListNameTextField.wmf_hasNonWhitespaceText
    }
    
    fileprivate var isDescriptionFieldEmpty: Bool {
        return !descriptionTextField.wmf_hasNonWhitespaceText
    }
    
    @IBAction func textFieldDidChange(_ textField: UITextField) {
        if readingListNameTextField.isFirstResponder {
            hideReadingListError()
        }
        createReadingListButton.isEnabled = !isReadingListNameFieldEmpty && readingListNameErrorLabel.isHidden
        showDoneReturnKeyIfNecessary()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        readingListNameTextField.becomeFirstResponder()
    }
    
    func showDoneReturnKeyIfNecessary() {
        if !isReadingListNameFieldEmpty && !isDescriptionFieldEmpty {
            descriptionTextField.returnKeyType = .done
        } else {
            descriptionTextField.returnKeyType = .default
        }
        if descriptionTextField.isFirstResponder {
            descriptionTextField.resignFirstResponder()
            descriptionTextField.becomeFirstResponder()
        } else {
            readingListNameTextField.resignFirstResponder()
            readingListNameTextField.becomeFirstResponder()
        }
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        guard !descriptionTextField.isFirstResponder else {
            createReadingListButtonPressed()
            return true
        }
        if readingListNameTextField.isFirstResponder {
            descriptionTextField.becomeFirstResponder()
        }
        return true
    }
    
    func textFieldShouldClear(_ textField: UITextField) -> Bool {
        if readingListNameTextField.isFirstResponder {
            hideReadingListError()
        }
        createReadingListButton.isEnabled = !isReadingListNameFieldEmpty && !readingListNameTextField.isFirstResponder && readingListNameErrorLabel.isHidden
        showDoneReturnKeyIfNecessary()
        return true
    }
}

extension CreateReadingListViewController: Themeable {
    func apply(theme: Theme) {
        self.theme = theme
        
        guard viewIfLoaded != nil else {
            return
        }
        
        view.backgroundColor = theme.colors.paperBackground
        view.tintColor = theme.colors.link
        
        readingListNameTextField.apply(theme: theme)
        descriptionTextField.apply(theme: theme)
        
        titleLabel.textColor = theme.colors.primaryText
        readingListNameLabel.textColor = theme.colors.secondaryText
        descriptionLabel.textColor = theme.colors.secondaryText
        readingListNameErrorLabel.textColor = theme.colors.error
        
        createReadingListButton.apply(theme: theme)
       
    }
}
