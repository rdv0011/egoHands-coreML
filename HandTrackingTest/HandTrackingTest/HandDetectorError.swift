import UIKit

// MARK: - Errors

enum HandDetectorError: Error {
    case captureSessionSetup(reason: String)
    case visionError(error: Error)
    case otherError(error: Error)

    static func display(_ error: Error, inViewController viewController: UIViewController) {
        if let appError = error as? HandDetectorError {
            appError.displayInViewController(viewController)
        } else {
            HandDetectorError.otherError(error: error).displayInViewController(viewController)
        }
    }

    func displayInViewController(_ viewController: UIViewController) {
        let title: String?
        let message: String?
        switch self {
        case .captureSessionSetup(let reason):
            title = "AVSession Setup Error"
            message = reason
        case .visionError(let error):
            title = "Vision Error"
            message = error.localizedDescription
        case .otherError(let error):
            title = "Error"
            message = error.localizedDescription
        }

        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))

        viewController.present(alert, animated: true, completion: nil)
    }
}
