//
//  File.swift
//  
//
//  Created by Yagiz Nizipli on 9/9/20.
//

import ObjectiveC
import SwiftUI

open class ProviderManager : AnalyticsProvider {
  private static let DeviceKey = "AnalyticsDeviceKey"
  
  private var userDefaults = UserDefaults.standard
  
  public weak var delegate : AnalyticsProviderDelegate?
  
  public private(set) var providers : [AnalyticsProvider] = []
  
  public var deviceId : String {
    #if !os(watchOS) && !os(macOS)
    if let advertisingIdentifier = advertisingIdentifier?.uuidString {
      return advertisingIdentifier
    }
    
    if let id = userDefaults.string(forKey: ProviderManager.DeviceKey) {
      return id
    }
    
    if let id = UIDevice.current.identifierForVendor?.uuidString {
      userDefaults.set(id, forKey: ProviderManager.DeviceKey)
      
      return id
    }
    #endif
    
    let id = ProviderManager.randomId()
    userDefaults.set(id, forKey: ProviderManager.DeviceKey)
    return id
  }
  
  public init () {}
  
  // - MARK: Public Methods
  
  /// If one of your providers requires launch options and application reference, this method must be called,
  /// or parameters must manually be provided.
  /// - Parameters:
  ///   - application: UIApplication instance
  ///   - launchOptions: launch options
  #if !os(watchOS) && !os(macOS)
  open func setup(with application: UIApplication?, launchOptions: [UIApplication.LaunchOptionsKey: Any]?) {
    var properties : Properties = [:]
    
    if let application = application {
      properties[Property.Launch.application.rawValue] = application
    }
    
    if let launchOptions = launchOptions {
      properties[Property.Launch.options.rawValue] = launchOptions
    }
    
    setup(with: properties)
  }
  #endif
  
  public func provider<T : AnalyticsProvider>(ofType type: T.Type) -> T? {
    return providers.filter { return ($0 is T) }.first as? T
  }
  
  public func addProvider(provider: AnalyticsProvider) {
    providers.append(provider)
  }
  
  public func setup(with properties: Properties? = nil) {
    providers.forEach { $0.setup(with: properties) }
  }
  public func activate() {
    providers.forEach { $0.activate() }
  }
  
  public func resign() {
    providers.forEach { $0.resign() }
  }
  
  public func flush() {
    providers.forEach { $0.flush() }
  }
  
  public func reset() {
    providers.forEach { $0.reset() }
  }
  
  public func event(_ event: AnalyticsEvent) {
    var event = event
    
    // Ask delegate for event. If delegate returns nil, skip the event delivery.
    if let delegate = delegate,
       let updatedEvent = delegate.providerShouldSendEvent(self, event: event) {
      event = updatedEvent
    }
    else if delegate != nil {
      return
    }
    
    providers.forEach { $0.event(event) }
    
    delegate?.providerDidSendEvent(self, event: event)
  }
  
  public func identify(userId: String, properties: Properties? = nil) {
    providers.forEach { $0.identify(userId: userId, properties: properties) }
  }
  
  public func alias(userId: String, forId: String) {
    providers.forEach { $0.alias(userId: userId, forId: forId) }
  }
  
  public func set(properties: Properties) {
    providers.forEach { $0.set(properties: properties) }
  }
  
  public func global(properties: Properties, overwrite: Bool) {
    providers.forEach { $0.global(properties: properties, overwrite: overwrite) }
  }
  
  public func increment(property: String, by number: NSDecimalNumber) {
    providers.forEach { $0.increment(property: property, by: number) }
  }
  
  public func addDevice(token: Data) {
    providers.forEach { $0.addDevice(token: token) }
  }
  
  public func setPushToken(token: String) {
    providers.forEach { $0.setPushToken(token: token) }
  }
  
  public func push(payload: [AnyHashable : Any], event: EventName?) {
    providers.forEach { $0.push(payload: payload, event: event) }
  }
  
  // MARK: Private Methods

  /// Returns advertising identifier if iAd.framework is linked.
  /// @note It uses Objective-C Runtime inspection, to detect,
  /// o no direct dependency to iAd is created in Swift.
  private var advertisingIdentifier : UUID? {
    guard let ASIdentifierManagerClass = NSClassFromString("ASIdentifierManager") else {
      return nil
    }
    
    let sharedManagerSelector = NSSelectorFromString("sharedManager")
    
    guard let sharedManagerIMP = ASIdentifierManagerClass.method(for: sharedManagerSelector) else {
      return nil
    }
    
    typealias sharedManagerFunc = @convention(c) (AnyObject, Selector) -> AnyObject?
    let curriedImplementation = unsafeBitCast(sharedManagerIMP, to: sharedManagerFunc.self)
    
    guard let sharedManager = curriedImplementation(ASIdentifierManagerClass.self, sharedManagerSelector) else {
      return nil
    }
    
    let advertisingTrackingEnabledSelector = NSSelectorFromString("isAdvertisingTrackingEnabled")
    
    guard let isTrackingEnabledIMP = sharedManager.method(for: advertisingTrackingEnabledSelector) else {
      return nil
    }
    
    typealias isTrackingEnabledFunc = @convention(c) (AnyObject, Selector) -> Bool
    let curriedImplementation2 = unsafeBitCast(isTrackingEnabledIMP, to: isTrackingEnabledFunc.self)
    let isTrackingEnabled = curriedImplementation2(self, advertisingTrackingEnabledSelector)
    
    guard isTrackingEnabled else {
      return nil
    }
    
    let advertisingIdentifierSelector = NSSelectorFromString("advertisingIdentifier")
    guard let advertisingIdentifierIMP = sharedManager.method(for: advertisingIdentifierSelector) else {
      return nil
    }
    
    typealias adIdentifierFunc = @convention(c) (AnyObject, Selector) -> UUID
    let curriedImplementation3 = unsafeBitCast(advertisingIdentifierIMP, to: adIdentifierFunc.self)
    
    return curriedImplementation3(self, advertisingIdentifierSelector)
  }
  
  private static func randomId(_ length: Int = 64) -> String {
    let charactersString = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
    let charactersArray : [Character] = Array(charactersString)
    
    let count = UInt32(charactersString.count)
    
    var string = ""
    
    for _ in 0..<length {
      let rand = Int(arc4random_uniform(count))
      
      string.append(charactersArray[rand])
    }
    
    return string
  }
}
