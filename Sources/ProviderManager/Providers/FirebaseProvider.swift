//
//  File.swift
//  
//
//  Created by Yagiz Nizipli on 9/9/20.
//

#if canImport(Firebase)

import ProviderManager
import Firebase
import FirebaseMessaging

public class FirebaseProvider : BaseProvider<Firebase.Analytics>, AnalyticsProvider {
  
  public func setup(with properties: Properties?) {
    FirebaseApp.configure()
    Messaging.messaging().delegate = self
  }
  
  public override func event(_ event: AnalyticsEvent) {
    guard let event = update(event: event) else {
      return
    }
    
    switch event.type {
    case .default:
      Analytics.logEvent(event.name, parameters: mergeGlobal(properties: event.properties, overwrite: true))
    case .finishTime:
      super.event(event)
      
      Analytics.logEvent(event.name, parameters: mergeGlobal(properties: event.properties, overwrite: true))
    default:
      super.event(event)
    }
    
    delegate?.providerDidSendEvent(self, event: event)
  }
  
  public func flush() {}
  
  public func reset() {
    Analytics.resetAnalyticsData()
  }
  
  public override func activate() {
    Analytics.logEvent(AnalyticsEventAppOpen, parameters: [:])
  }
  
  public func identify(userId: String, properties: Properties?) {
    Analytics.setUserID(userId)
    
    if let properties = properties {
      set(properties: properties)
    }
  }
  
  public func alias(userId: String, forId: String) {}
  
  public func set(properties: Properties) {
    
    let properties = prepare(properties: properties)!
    
    for (property, value) in properties {
      if let value = value as? String {
        Analytics.setUserProperty(value, forName: property)
      }
      else {
        Analytics.setUserProperty(String(describing: value), forName: property)
      }
    }
  }
  
  public func increment(property: String, by number: NSDecimalNumber) {}
  
  public override func addDevice(token: Data) {
    Messaging.messaging().apnsToken = token
  }
  
  public override func setPushToken(token: String) {
    
  }
  
  public override func update(event: AnalyticsEvent) -> AnalyticsEvent? {
    //
    // Ensure Super gets a chance to update event.
    //
    guard var event = super.update(event: event) else {
      return nil
    }
    
    //
    // Update event name and properties based on Facebook's values
    //
    
    if let defaultName = DefaultEvent(rawValue: event.name),
       let updatedName = parse(name: defaultName) {
      event.name = updatedName
    }
    
    event.properties = prepare(properties: mergeGlobal(properties: event.properties, overwrite: true))
    
    return event
  }
  
  //
  // MARK: Private Methods
  //
  
  private func parse(name: DefaultEvent) -> String? {
    switch name {
    case .addedPaymentInfo:
      return AnalyticsEventAddPaymentInfo
    case .addedToWishlist:
      return AnalyticsEventAddToWishlist
    case .completedTutorial:
      return AnalyticsEventTutorialComplete
    case .addedToCart:
      return AnalyticsEventAddToCart
    case .viewContent:
      return AnalyticsEventSelectContent
    case .initiatedCheckout:
      return AnalyticsEventBeginCheckout
    case .campaignEvent:
      return AnalyticsEventCampaignDetails
    case .checkoutProgress:
      return AnalyticsEventCheckoutProgress
    case .earnCredits:
      return AnalyticsEventEarnVirtualCurrency
    case .purchase:
      return AnalyticsEventEcommercePurchase
    case .joinGroup:
      return AnalyticsEventJoinGroup
    case .generateLead:
      return AnalyticsEventGenerateLead
    case .levelUp:
      return AnalyticsEventLevelUp
    case .signUp:
      return AnalyticsEventLogin
    case .postScore:
      return AnalyticsEventPostScore
    case .presentOffer:
      return AnalyticsEventPresentOffer
    case .refund:
      return AnalyticsEventPurchaseRefund
    case .removeFromCart:
      return AnalyticsEventRemoveFromCart
    case .search:
      return AnalyticsEventSearch
    case .checkoutOption:
      return AnalyticsEventSetCheckoutOption
    case .share:
      return AnalyticsEventShare
    case .completedRegistration:
      return AnalyticsEventSignUp
    case .spendCredits:
      return AnalyticsEventSpendVirtualCurrency
    case .unlockedAchievement:
      return AnalyticsEventUnlockAchievement
    case .viewItem:
      return AnalyticsEventViewItem
    case .viewItemList:
      return AnalyticsParameterItemList
    case .searchResults:
      return AnalyticsEventViewSearchResults
    default:
      return nil
    }
  }
  
  private func prepare(properties: Properties?) -> Properties? {
    guard let properties = properties else {
      return nil
    }
    
    var finalProperties : Properties = properties
    
    for (property, value) in properties {
      
      let property = parse(property: property)
      
      if let parsed = parse(value: value) {
        finalProperties[property] = parsed
      }
    }
    
    return finalProperties
  }
  
  private func parse(property: String) -> String {
    switch property {
    case Property.Purchase.quantity.rawValue:
      return AnalyticsParameterQuantity
    case Property.Purchase.item.rawValue:
      return AnalyticsParameterItemName
    case Property.Purchase.sku.rawValue:
      return AnalyticsParameterItemID
    case Property.Purchase.category.rawValue:
      return AnalyticsParameterItemCategory
    case Property.Purchase.source.rawValue:
      return AnalyticsParameterItemLocationID
    case Property.Purchase.price.rawValue:
      return AnalyticsParameterValue
    case Property.Purchase.currency.rawValue:
      return AnalyticsParameterCurrency
    case Property.Location.origin.rawValue:
      return AnalyticsParameterOrigin
    case Property.Location.destination.rawValue:
      return AnalyticsParameterDestination
    case Property.startDate.rawValue:
      return AnalyticsParameterStartDate
    case Property.endDate.rawValue:
      return AnalyticsParameterEndDate
    case Property.Purchase.medium.rawValue:
      return AnalyticsParameterMedium
    case Property.Purchase.campaign.rawValue:
      return AnalyticsParameterCampaign
    case Property.term.rawValue:
      return AnalyticsParameterTerm
    case Property.Content.identifier.rawValue:
      return AnalyticsParameterContent
    case Property.User.registrationMethod.rawValue:
      return AnalyticsParameterSignUpMethod
    default:
      return property
    }
  }
  
  private func parse(value: Any) -> Any? {
    if let string = value as? String {
      if string.count > 35 {
        let maxTextSize = string.index(string.startIndex, offsetBy: 35)
        let substring = string[..<maxTextSize]
        return String(substring)
      }
      
      return value
    }
    
    if let number = value as? Int {
      return NSNumber(value: number)
    }
    
    if let number = value as? UInt {
      return NSNumber(value: number)
    }
    
    if let number = value as? Bool {
      return NSNumber(value: number)
    }
    
    if let number = value as? Float {
      return NSNumber(value: number)
    }
    
    if let number = value as? Double {
      return NSNumber(value: number)
    }
    
    return nil
  }
}

extension FirebaseProvider: MessagingDelegate, UNUserNotificationCenterDelegate {
  
  public func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String) {
    NotificationCenter.default.post(name: Notification.Name("FCMToken"),
                                    object: nil,
                                    userInfo: ["token": fcmToken])
  }
}

#endif
