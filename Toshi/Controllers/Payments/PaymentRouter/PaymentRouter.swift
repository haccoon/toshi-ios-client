// Copyright (c) 2017 Token Browser, Inc
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <http://www.gnu.org/licenses/>.

import Foundation

protocol PaymentRouterDelegate: class {
    func paymentRouterDidCancel(paymentRouter: PaymentRouter)
    func paymentRouterDidSucceedPayment(_ paymentRouter: PaymentRouter, parameters: [String: Any], transactionHash: String?, unsignedTransaction: String?, error: ToshiError?)
}

extension PaymentRouterDelegate {
    func paymentRouterDidCancel(paymentRouter: PaymentRouter) {}
}

final class PaymentRouter {
    weak var delegate: PaymentRouterDelegate?

    var userInfo: UserInfo?
    var dappInfo: DappInfo?
    private var shouldSendSignedTransaction = true
    var additionalParamaters: [String: Any]?

    private var paymentViewModel: PaymentViewModel

    init(withAddress address: String? = nil, andValue value: NSDecimalNumber? = nil, gasPrice: String? = nil, shouldSendSignedTransaction: Bool = true, additionalParams: [String: Any]? = nil) {
        self.paymentViewModel = PaymentViewModel(recipientAddress: address, value: value, gasPrice: gasPrice)
        self.shouldSendSignedTransaction = shouldSendSignedTransaction
        self.additionalParamaters = additionalParams
    }

    // I purposefully created this method so the caller is aware that this object will present a VC
    func present() {
        //here should be decided what controller should be presented first
        guard let value = paymentViewModel.value else {
            presentPaymentValueController()
            return
        }

        guard let address = paymentViewModel.recipientAddress, EthereumAddress.validate(address) else {
            presentRecipientAddressController(withValue: value)
            return
        }

        presentPaymentConfirmationController(withValue: value, andRecipientAddress: address)
    }

    private func presentPaymentValueController() {
        let paymentValueController = PaymentController(withPaymentType: .send, continueOption: .next)
        paymentValueController.delegate = self

        presentViewControllerOnNavigator(paymentValueController)
    }

    private func presentRecipientAddressController(withValue value: NSDecimalNumber) {
        let addressController = PaymentAddressController(with: value)
        addressController.delegate = self

        presentViewControllerOnNavigator(addressController)
    }

    private func presentPaymentConfirmationController(withValue value: NSDecimalNumber, andRecipientAddress address: String) {

        if let dappInfo = dappInfo {
            let paymentConfirmationController = PaymentConfirmationViewController(withValue: value, andRecipientAddress: address, gasPrice: paymentViewModel.gasPrice, recipientType: .dapp(info: dappInfo), shouldSendSignedTransaction: shouldSendSignedTransaction, skeletonParams: additionalParamaters)
            paymentConfirmationController.delegate = self
            paymentConfirmationController.modalPresentationStyle = .currentContext

            Navigator.presentModally(paymentConfirmationController)
        } else {
            let paymentConfirmationController = PaymentConfirmationViewController(withValue: value, andRecipientAddress: address, recipientType: .user(info: userInfo), shouldSendSignedTransaction: shouldSendSignedTransaction)
            paymentConfirmationController.delegate = self

            let navigationController = PaymentNavigationController(rootViewController: paymentConfirmationController)
            Navigator.presentModally(navigationController)
        }
    }

    private func presentViewControllerOnNavigator(_ controller: UIViewController) {

        if controller is PaymentConfirmationViewController {
            let navigationController = PaymentNavigationController(rootViewController: controller)
            Navigator.presentModally(navigationController)
        } else if let paymentNavigationController = Navigator.topViewController as? PaymentNavigationController {
            paymentNavigationController.pushViewController(controller, animated: true)
        } else {
            let navigationController = PaymentNavigationController(rootViewController: controller)
            Navigator.presentModally(navigationController)
        }
    }
}

extension PaymentRouter: PaymentControllerDelegate {
    func paymentValueControllerFinished(with valueInWei: NSDecimalNumber, on controller: PaymentController) {
        paymentViewModel.setValue(valueInWei)
        present()
    }
}

extension PaymentRouter: PaymentAddressControllerDelegate {
    func paymentAddressControllerFinished(with address: String, on controller: PaymentAddressController) {
        paymentViewModel.setAddress(address)
        present()
    }
}

extension PaymentRouter: PaymentConfirmationViewControllerDelegate {

    func paymentConfirmationViewControllerFinished(on controller: PaymentConfirmationViewController, parameters: [String: Any], transactionHash: String?, error: ToshiError?) {

        if Navigator.topViewController is PaymentNavigationController {
            Navigator.rootViewController?.dismiss(animated: true)
        }

        self.delegate?.paymentRouterDidSucceedPayment(self, parameters: parameters, transactionHash: transactionHash, unsignedTransaction: controller.originalUnsignedTransaction, error: error)
    }

    func paymentConfirmationViewControllerDidCancel(on controller: PaymentConfirmationViewController) {
        Navigator.topViewController?.dismiss(animated: true)
    }
}