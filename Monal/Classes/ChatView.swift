//
//  ChatView.swift
//  Monal
//
//  Created by Thilo Molitor on 05.09.24.
//  Copyright © 2024 monal-im.org. All rights reserved.
//

import FrameUp
import ExyteChat
import SwiftUI
import Markdown // You may want to import a Markdown parsing library or implement your own.

typealias ExyteChatView = ExyteChat.ChatView

struct ChatView: View {
    @Environment(\.presentationMode) private var presentationMode
    
    @StateObject var contact: ObservableKVOWrapper<MLContact>
    @State private var selectedContactForContactDetails: ObservableKVOWrapper<MLContact>?
    @State private var alertPrompt: AlertPrompt?
    @State private var confirmationPrompt: ConfirmationPrompt?
    @StateObject private var overlay = LoadingOverlayState()
    @State var messages: [ChatViewMessage] = []
    private var account: xmpp
    
    init(contact: ObservableKVOWrapper<MLContact>) {
        _contact = StateObject(wrappedValue: contact)
        account = contact.obj.account!
    }
    
    private func showCannotEncryptAlert(_ show: Bool) {
        if show {
            DDLogVerbose("Showing cannot encrypt alert...")
            alertPrompt = AlertPrompt(
                title: Text("Encryption Not Supported"),
                message: Text("This contact does not appear to have any devices that support encryption, please try again later if you think this is wrong."),
                dismissLabel: Text("Close")
            )
        } else {
            alertPrompt = nil
        }
    }
    
    private func showShouldDisableEncryptionConfirmation(_ show: Bool) {
        if show {
            DDLogVerbose("Showing should disable encryption confirmation...")
            confirmationPrompt = ConfirmationPrompt(
                title: Text("Disable encryption?"),
                message: Text("Do you really want to disable encryption for this contact?"),
                buttons: [
                    .cancel(
                        Text("No, keep encryption activated"),
                        action: { }
                    ),
                    .destructive(
                        Text("Yes, deactivate encryption"),
                        action: {
                            showCannotEncryptAlert(!contact.obj.toggleEncryption(!contact.isEncrypted))
                        }
                    )
                ]
            )
        } else {
            confirmationPrompt = nil
        }
    }
    
    private func checkOmemoSupport(withAlert showWarning: Bool) {
#if !DISABLE_OMEMO
    if DataLayer.sharedInstance().isAccountEnabled(contact.accountID) {
        var omemoDeviceForContactFound = false
        if !contact.isMuc {
            omemoDeviceForContactFound = account.omemo.knownDevices(forAddressName:contact.contactJid).count > 0
        } else {
            omemoDeviceForContactFound = false
            for participant in DataLayer.sharedInstance().getMembersAndParticipants(ofMuc:contact.contactJid, forAccountID:contact.accountID) {
                if let participant_jid = participant["participant_jid"] as? String {
                    omemoDeviceForContactFound = omemoDeviceForContactFound || account.omemo.knownDevices(forAddressName:participant_jid).count > 0
                } else if let participant_jid = participant["member_jid"] as? String {
                    omemoDeviceForContactFound = omemoDeviceForContactFound || account.omemo.knownDevices(forAddressName:participant_jid).count > 0
                }
                if omemoDeviceForContactFound {
                    break
                }
            }
        }
        if !omemoDeviceForContactFound && contact.isEncrypted {
            if HelperTools.isContactBlacklistedForEncryption(contact.obj) {
                // this contact was blacklisted for encryption
                // --> disable it
                contact.isEncrypted = false
                DataLayer.sharedInstance().disableEncrypt(forJid:contact.contactJid, andAccountID:contact.accountID)
            } else if contact.isMuc && contact.mucType != kMucTypeGroup {
                // a channel type muc has OMEMO encryption enabled, but channels don't support encryption
                // --> disable it
                contact.isEncrypted = false
                DataLayer.sharedInstance().disableEncrypt(forJid:contact.contactJid, andAccountID:contact.accountID)
            } else if !contact.isMuc || (contact.isMuc && contact.mucType == kMucTypeGroup) {
                hideLoadingOverlay(overlay)
                
                if showWarning {
                    DDLogWarn("Showing omemo not supported alert for: \(self.contact)")

                    alertPrompt = AlertPrompt(
                        title: Text("No OMEMO keys found"),
                        message: Text("This contact may not support OMEMO encrypted messages. Please try to enable encryption again in a few seconds, if you think this is wrong."),
                        dismissLabel: Text("Disable Encryption")
                    ) {
                        contact.isEncrypted = false
                        DataLayer.sharedInstance().disableEncrypt(forJid:contact.contactJid, andAccountID:contact.accountID)
                    }
                } else {
                    DDLogInfo("Trying to fetch omemo keys for: \(self.contact)")
                    
                    // we won't do this twice, because the user won't be able to change isEncrypted to YES,
                    // unless we have omemo devices for that contact
                    showPromisingLoadingOverlay(overlay, headlineView:Text("Loading OMEMO keys"), descriptionView:Text("")).done {
                        // request omemo devicelist
                        account.omemo.subscribeAndFetchDevicelistIfNoSessionExists(forJid:contact.contactJid)
                    }
                }
            }
        } else {
            hideLoadingOverlay(overlay)
        }
    }
#endif
}
    
    var body: some View {
        ExyteChatView(messages: messages, chatType: .conversation, replyMode: .quote) { draft in
            print("sending draft: \(String(describing:draft))")
        } messageBuilder: { message, positionInUserGroup, positionInCommentsGroup, showContextMenuClosure, messageActionClosure, showAttachmentClosure in
            MessageView(message: ObservableKVOWrapper((message as! ChatViewMessage).message))
        }
        .sheet(item: $selectedContactForContactDetails) { selectedContact in
            AnyView(AddTopLevelNavigation(withDelegate:nil, to:ContactDetails(delegate:nil, contact:selectedContact)))
        }
        .actionSheet(isPresented: $confirmationPrompt.optionalMappedToBool()) {
            ActionSheet(title: confirmationPrompt!.title, message: confirmationPrompt!.message, buttons: confirmationPrompt!.buttons)
        }
        .alert(isPresented: $alertPrompt.optionalMappedToBool()) {
            let callback = alertPrompt!.dismissCallback
            return Alert(title: alertPrompt!.title, message: alertPrompt!.message, dismissButton:.default(alertPrompt!.dismissLabel, action: {
                if let callback = callback {
                    callback()
                }
            }))
        }
        .toolbar {
            ToolbarItem(placement: .principal) {
                ZStack {
                    Color.clear
                    HStack {
                        Button {
                            selectedContactForContactDetails = contact
                        } label: {
                            HStack {
                                Image(uiImage: contact.avatar)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 35, height: 35)
                                    .clipShape(Circle())

                                VStack(alignment: .leading, spacing: 0) {
                                    Text(contact.contactDisplayName as String)
                                        .fontWeight(.semibold)
                                        .font(.headline)
                                        .foregroundColor(.black)
                                    
                                    if (contact.isTyping as Bool) {
                                        Text("Typing...")
                                            .font(.footnote)
                                            .foregroundColor(Color(hex: "AFB3B8"))
                                    } else if let lastInteractionDate:Date = contact.lastInteractionTime {
                                        Text(HelperTools.formatLastInteraction(lastInteractionDate))
                                            .font(.footnote)
                                            .foregroundColor(Color(hex: "AFB3B8"))
                                    }
                                }
                            }
                        }
                        Spacer()
                    }
                }
            }
            
            ToolbarItemGroup(placement: .topBarTrailing) {
                if !(contact.isMuc || contact.isSelfChat) {
                    let activeChats = (UIApplication.shared.delegate as! MonalAppDelegate).activeChats!
                    let voipProcessor = (UIApplication.shared.delegate as! MonalAppDelegate).voipProcessor!
                    Button {
                        if let activeCall = voipProcessor.getActiveCall(with:contact.obj) {
                            if !DataLayer.sharedInstance().checkCap("urn:xmpp:jingle-message:0", forUser:contact.contactJid, onAccountID:contact.accountID) {
                                confirmationPrompt = ConfirmationPrompt(
                                    title: Text("Missing Call Support"),
                                    message: Text("Your contact may not support calls. Your call might never reach its destination."),
                                    buttons: [
                                        .default(
                                            Text("Try nevertheless"),
                                            action: {
                                                activeChats.call(contact.obj, withUIKitSender:nil)
                                            }
                                        ),
                                        .cancel(
                                            Text("Cancel"),
                                            action: { }
                                        )
                                    ]
                                )
                            }
                        } else {
                                activeChats.call(contact.obj, withUIKitSender:nil)
                        }
                    } label: {
                        Image(systemName: "phone.fill")
                            .foregroundColor(Color.monalPrimary)
                            .imageScale(.large)
                    }
                }
            }
        }
    }
    
    private func parseMessageStyles(_ message: String) -> AttributedString {
        var attributedMessage = AttributedString(message)
        
        // Parse bold syntax
        if let boldRange = message.range(of: "\\*[^*]+\\*", options: .regularExpression) {
            attributedMessage.addAttributes([.font: Font.boldSystemFont(ofSize: 16)], range: NSRange(boldRange, in: message))
        }
        
        // Parse italics syntax
        if let italicsRange = message.range(of: "_([^_]+)_", options: .regularExpression) {
            attributedMessage.addAttributes([.font: Font.italicSystemFont(ofSize: 16)], range: NSRange(italicsRange, in: message))
        }

        // Parse code blocks syntax
        if let codeRange = message.range(of: "`[^`]+`", options: .regularExpression) {
            attributedMessage.addAttributes([.font: Font.monospacedSystemFont(ofSize: 16, weight: .regular)], range: NSRange(codeRange, in: message))
        }
        
        return attributedMessage
    }
}
