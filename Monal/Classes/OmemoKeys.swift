//
//  OmemoKeys.swift
//  Monal
//
//  Created by Jan on 04.05.22.
//  Copyright © 2022 Monal.im. All rights reserved.
//

import OrderedCollections

struct OmemoKeysEntry: View {
    private let contactJid: String
    
    @State private var trustLevel: NSNumber
    @State private var showEntryInfo = false
    @State private var showClipboardCopy = false

    private let deviceId: NSNumber
    private let fingerprint: Data
    private let address: SignalAddress
    private let account: xmpp
    private let isOwnDevice: Bool
    private let isBrokenSession: Bool
    
    init(account: xmpp, contactJid: String, deviceId: NSNumber, isOwnDevice: Bool) {
        self.contactJid = contactJid
        self.deviceId = deviceId
        self.isOwnDevice = isOwnDevice
        self.address = SignalAddress.init(name: contactJid, deviceId: Int32(deviceId.int32Value))
        self.fingerprint = account.omemo.getIdentityFor(self.address)
        self.trustLevel = account.omemo.getTrustLevel(self.address, identityKey: self.fingerprint)
        self.account = account
        self.isBrokenSession = account.omemo.isSessionBroken(forJid:contactJid, andDeviceId:deviceId)
    }
    
    func setTrustLevel(_ enableTrust: Bool) {
        self.account.omemo.updateTrust(enableTrust, for: self.address)
        self.trustLevel = self.account.omemo.getTrustLevel(self.address, identityKey: self.fingerprint)
    }

    func getEntryInfoAlert() -> Alert {
        if(self.isOwnDevice) {
            return Alert(
                title: Text("Own device key"),
                message: Text("This key belongs to this device and cannot be removed or disabled!"),
                dismissButton: nil);
        }
        switch(self.trustLevel.int32Value) {
        case MLOmemoTrusted:
            return Alert(
                title: Text("Trusted and verified key"),
                message: Text("This key is trusted and verified by manually comparing fingerprints. To stop trusting this key, use the toggle element."),
                dismissButton: nil)
        case MLOmemoToFU:
            return Alert(
                title: Text("Trusted but unverified key"),
                message: Text("Monal currently trusts this key, but fingerprints were not compared yet. To increase security, please confirm with the contact that the displayed fingerprints do match before trusting this key!"),
                primaryButton: .destructive(Text("Trust Key"), action: {
                    setTrustLevel(true)
                }),
                secondaryButton: .default(Text("Okay")))
        case MLOmemoNotTrusted:
            return Alert(
                title: Text("Untrusted key"),
                message: Text("Monal does not trust this key. Either it was manually disabled or not manually verified while other keys of that contact are verified. You can trust this key by using the toggle element. Please ensure with the contact that fingerprints are matching before trusting this key."),
                dismissButton: nil)
        case MLOmemoTrustedButRemoved:
            return Alert(
                title: Text("Trusted but removed key"),
                message: Text("This key is trusted, but the contact does not use it anymore. Consider to disable trust for this key."),
                primaryButton: .default(Text("Dont' trust Key"), action: {
                    setTrustLevel(false)
                }),
                secondaryButton: .cancel(Text("Okay")))
        case MLOmemoTrustedButNoMsgSeenInTime:
            return Alert(
                title: Text("Trusted but unused key"),
                message: Text("This key is trusted, but the contact has not used it for a long time. Consider to disable trust for this key"),
                primaryButton: .default(Text("Don't trust Key"), action: {
                    setTrustLevel(false)
                }),
                secondaryButton: .cancel(Text("Okay")))
        default:
            return Alert(
                title: Text("Invalid State"),
                message: Text("The key is in a state that is currently not correctly handled. Please contact the developers if you see this prompt."),
                dismissButton: nil)
        }
    }

    // @ViewBuilder
    func getTrustLevelIcon() -> some View {
        var accentColor = Color.yellow
        var iconName = "key.fill"
        switch(self.trustLevel.int32Value) {
        case MLOmemoTrusted:
            accentColor = Color.green
            break
        case MLOmemoToFU:
            break
        case MLOmemoNotTrusted:
            accentColor = Color.red
            break
        case MLOmemoTrustedButRemoved:
            iconName = "trash.fill"
        case MLOmemoTrustedButNoMsgSeenInTime:
            iconName = "clock.fill"
        default:
            break
        }
        return Image(systemName: iconName)
            .frame(width: 30, height: 30, alignment: .center)
            .foregroundColor(Color.primary)
            .background(accentColor)
            .cornerRadius(30)
    }

    func getDeviceIconForOwnDevice() -> some View {
        var deviceImage: String = "iphone.homebutton.circle"
        if UIDevice.current.userInterfaceIdiom == .pad {
#if targetEnvironment(macCatalyst)
            deviceImage = "laptopcomputer"
#else
            deviceImage = "ipad"
#endif
        }
        return Image(systemName: deviceImage)
            .resizable()
            .frame(width: 30, height: 30, alignment: .center)
            .foregroundColor(Color.primary)
    }

    var body: some View {
        let trustLevelBinding = Binding<Bool>.init(get: {
            return (self.trustLevel.int32Value != MLOmemoNotTrusted)
        }, set: { keyEnabled in
            setTrustLevel(keyEnabled)
        })

        let fingerprintString = HelperTools.signalHexKeyWithSpaces(with: fingerprint)
        let clipboardValue = "OMEMO fingerprint of \(self.contactJid), device \(self.deviceId): \(fingerprintString)"
        GroupBox {
            HStack(alignment:.bottom) {
                VStack(alignment:.leading) {
                    HStack(alignment:.center) {
                        Text("Device ID: ").font(.headline)
                        Text(deviceId.stringValue)
                    }
                    Spacer()
                    HStack(alignment:.center) {
                        Text(fingerprintString)
                            .font(Font.init(
                                UIFont.monospacedSystemFont(ofSize: 11.0, weight: .regular)
                            ))
                        if(self.isBrokenSession) {
                            Text("Encrypted session to this device broken beyond repair.").foregroundColor(.red)
                        }
                    }
                }
                .onTapGesture(count: 2) {
                    UIPasteboard.general.setValue(clipboardValue, forPasteboardType:UTType.utf8PlainText.identifier)
                    showClipboardCopy = true
                }
                Spacer()
                // the trust level of our own device should not be displayed
                if(!isOwnDevice) {
                    VStack(alignment:.center) {
                        Button {
                            showEntryInfo = true
                        } label: {
                            getTrustLevelIcon()
                        }
                        Toggle("", isOn: trustLevelBinding).font(.footnote)
                        .labelsHidden()     //make sure we do not need more space than the actual toggle needs
                    }
                } else {
                    Button {
                        showEntryInfo = true
                    } label: {
                        getDeviceIconForOwnDevice()
                    }
                }
            }
            .alert(isPresented: $showEntryInfo) {
                getEntryInfoAlert()
            }
            .alert(isPresented: $showClipboardCopy) {
                Alert(
                    title: Text("Copied to clipboard"),
                    message: Text(clipboardValue),
                    dismissButton: nil
                );
            }
        }
    }
}

struct OmemoKeysForContact: View {
    @State private var deviceId: NSNumber
    @State private var deviceIds: OrderedSet<NSNumber>
    @State private var showDeleteKeyAlert = false
    @State private var selectedDeviceForDeletion : NSNumber

    private let contactJid: String
    private let account: xmpp
    private let ownKeys: Bool

    init(contact: ObservableKVOWrapper<MLContact>, account: xmpp) {
        self.ownKeys = (account.connectionProperties.identity.jid == contact.obj.contactJid)
        self.contactJid = contact.obj.contactJid
        self.account = account
        self.deviceId = account.omemo.getDeviceId()
        self.deviceIds = OmemoKeysForContact.knownDevices(account: self.account, jid: self.contactJid)
        self.selectedDeviceForDeletion = -1
    }
    
    private static func knownDevices(account: xmpp, jid: String) -> OrderedSet<NSNumber> {
        return OrderedSet(account.omemo.knownDevices(forAddressName: jid).sorted { return $0.intValue < $1.intValue })
    }

    private func refreshKnownDevices() -> Void {
        self.deviceIds = OmemoKeysForContact.knownDevices(account: self.account, jid: self.contactJid)
    }

    func deleteButton(deviceId: NSNumber) -> some View {
        Button(action: {
            selectedDeviceForDeletion = deviceId // SwiftUI does not like to have deviceID nested in multiple functions, so safe this in the struct...
            showDeleteKeyAlert = true
        }, label: {
            Image(systemName: "xmark.circle.fill").foregroundColor(.red)
        })
        .buttonStyle(.borderless)
        .offset(x: -7, y: -7)
        .alert(isPresented: $showDeleteKeyAlert) {
            Alert(
                title: Text("Do you really want to delete this key?"),
                message: Text("DeviceID: " + self.selectedDeviceForDeletion.stringValue),
                primaryButton: .destructive(Text("Delete Key")) {
                    if(deviceId == -1) {
                        return // should be unreachable
                    }
                    account.omemo.deleteDevice(forSource: self.contactJid, andRid: self.selectedDeviceForDeletion)
                },
                secondaryButton: .cancel(Text("Abort"))
            )
        }
    }
    
    var body: some View {
        ForEach(self.deviceIds, id: \.self) { deviceId in
            HStack {
                ZStack(alignment: .topLeading) {
                    OmemoKeysEntry(account: self.account, contactJid: self.contactJid, deviceId: deviceId, isOwnDevice: (ownKeys && deviceId == self.deviceId))
                    if(ownKeys == true) {
                        if(deviceId != self.deviceId) {
                            deleteButton(deviceId: deviceId)
                        }
                    }
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("kMonalOmemoStateUpdated")).receive(on: RunLoop.main)) { notification in
            if notification.userInfo?["jid"] as? String == self.contactJid {
                withAnimation() {
                    refreshKnownDevices()
                }
            }
        }
    }
}

struct OmemoKeys: View {
    private var ownKeys: Bool
    private var viewContact: ObservableKVOWrapper<MLContact>? // store initial contact with which the view was initialized for refreshs...
    private var account: xmpp?

    // Needed for the alert message that is displayed when the scanned contact is not in the group
    @State private var scannedJid : String = ""
    @State private var scannedFingerprints : Dictionary<NSInteger, String> = [:]

    @State private var contacts: OrderedSet<ObservableKVOWrapper<MLContact>> // contact list may change/be reloaded -> state

    @State var selectedContact : ObservableKVOWrapper<MLContact>? // for reason why see start of body
    @State private var navigateToQRCodeView = false
    @State private var navigateToQRCodeScanner = false

    @State private var showScannedContactMissmatchAlert = false

    init(contact: ObservableKVOWrapper<MLContact>?) {
        self.account = nil
        self.ownKeys = false
        self.selectedContact = nil
        self.contacts = getContactList(viewContact: contact)
        self.viewContact = contact

        if let contact = contact {
            if let account = MLXMPPManager.sharedInstance().getConnectedAccount(forID: contact.accountId) {
                self.account = account
                self.ownKeys = (!(contact.isGroup && contact.mucType == "group") && self.account!.connectionProperties.identity.jid == contact.contactJid)
            }
        }
    }

    func resetTrustFromQR(scannedJid : String, scannedFingerprints : Dictionary<NSInteger, String>) {
        //don't untrust other devices not included in here, because conversations only exports its own fingerprint
//         // untrust all devices from jid
//         self.account!.omemo.untrustAllDevices(from: scannedJid)
        // trust all devices that were part of the qr code
        let knownDevices = Array(self.account!.omemo.knownDevices(forAddressName: scannedJid))
        for (qrDeviceId, fingerprint) in scannedFingerprints {
            let address = SignalAddress(name: scannedJid, deviceId: Int32(qrDeviceId))
            let identityFromHex = HelperTools.signalIdentity(withHexKey: fingerprint)
            // insert fingerprint of unkown devices to signalstore
            if(!knownDevices.contains(NSNumber(integerLiteral: qrDeviceId))) {
                self.account!.omemo.addIdentityManually(address, identityKey: identityFromHex)
                assert(self.account!.omemo.getIdentityFor(address) == identityFromHex, "The stored and created fingerprint should match")
            }
            // trust device/fingerprint if fingerprints match
            let identity = self.account!.omemo.getIdentityFor(address)
            let knownIdentity = HelperTools.signalHexKey(with: identity)
            if(knownIdentity.uppercased() == fingerprint.uppercased()) {
                self.account!.omemo.updateTrust(true, for: address)
            }
        }
    }

    var body: some View {
        // workaround for the fact that NavigationLink inside a form forces a formatting we don't want
        if(self.selectedContact != nil) { // selectedContact is set to a value either when the user presses a QR code button or if there is only a single contact to choose from (-> user views a single account)
            NavigationLink(destination:LazyClosureView(OmemoQrCodeView(contact: self.selectedContact!)), isActive: $navigateToQRCodeView){}.hidden().disabled(true) // navigation happens as soon as our button sets navigateToQRCodeView to true...
//             NavigationLink(destination: LazyClosureView(MLQRCodeScanner(
//                 handleContact: { jid, fingerprints in
//                     // we scanned a contact but it was not in the contact list, show the alert...
//                     self.scannedJid = jid
//                     self.scannedFingerprints = fingerprints
//                     showScannedContactMissmatchAlert = true
//                 }, handleClose: {}
//             )), isActive: $navigateToQRCodeScanner){}.hidden().disabled(true)
        }
        List {
            let helpDescription = (self.ownKeys == true) ?
            Text("These are your encryption keys. Each device is a different place you have logged in. You should trust a key when you have verified it. Double tap onto a fingerprint to copy to clipboard.") :
            Text("You should trust a key when you have verified it. Verify by comparing the key below to the one on your contact's screen. Double tap onto a fingerprint to copy to clipboard.")

            Section(header:helpDescription) {
                if(self.contacts.count == 0) {
                    Text("Error: No contacts to display keys for!").foregroundColor(.red).font(.headline)
                } else if(self.account == nil) {
                    Text("Error: Account disabled, can not display keys!").foregroundColor(.red).font(.headline)
                } else if (self.contacts.count == 1) {
                    ForEach(self.contacts, id: \.self.obj) { contact in
                        OmemoKeysForContact(contact: contact, account: self.account!)
                    }
                } else {
                    ForEach(self.contacts, id: \.self.obj) { contact in
                        DisclosureGroup(content: {
                            OmemoKeysForContact(contact: contact, account: self.account!)
                        }, label: {
                            HStack {
                                Text("Keys of \(contact.obj.contactJid)")
                                Spacer()
                                Button(action: {
                                    self.selectedContact = contact
                                    self.navigateToQRCodeView = true
                                }, label: {
                                    Image(systemName: "qrcode.viewfinder")
                                }).buttonStyle(.borderless)
                            }
                        })
                    }
                }
            }
        }
        .listStyle(.plain)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack{
                    /*if(self.account != nil) {
                        Button(action: {
                            self.navigateToQRCodeScanner = true
                        }, label: {
                            Image(systemName: "camera.fill")
                        })
                    }*/
                    if(self.contacts.count == 1 && self.account != nil) {
                        Button(action: {
                            self.navigateToQRCodeView = true
                        }, label: {
                            Image(systemName: "qrcode.viewfinder")
                        })
                    }
                }
            }
        }
        .accentColor(monalGreen)
        .navigationBarTitle((self.ownKeys == true) ? Text("My Encryption Keys") : Text("Encryption Keys"), displayMode: .inline)
        .onAppear(perform: {
            self.selectedContact = self.contacts.first // needs to be done here as first is nil in init
        })
        .alert(isPresented: $showScannedContactMissmatchAlert) {
            Alert(
                title: Text("QR code: Fingerprints found"),
                message: Text("Do you want to trust the scanned fingerprints of contact \(self.scannedJid) when using your account \(self.account!.connectionProperties.identity.jid)?"),
                primaryButton: .cancel(Text("No")),
                secondaryButton: .default(Text("Yes"), action: {
                    resetTrustFromQR(scannedJid: self.scannedJid, scannedFingerprints: self.scannedFingerprints)
                    self.scannedJid = ""
                    self.scannedFingerprints = [:]
                    self.contacts = getContactList(viewContact: self.viewContact) // refresh all contacts because trust may have changed
            }))
        }
    }
}

struct OmemoKeys_Previews: PreviewProvider {
    static var previews: some View {
        // TODO some dummy views, requires a dummy xmpp obj
        OmemoKeys(contact:nil);
    }
}
