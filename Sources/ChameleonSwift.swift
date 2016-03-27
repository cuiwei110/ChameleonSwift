//
//  ChameleonSwift.swift
//  ChameleonSwift
//
//  Created by travel on 16/3/19.
//  Copyright © 2016年 travel. All rights reserved.
//

import Foundation
import UIKit

private class ThemeSwitchData {
    var lastTimestamp:Int64 = 0
    var lastSignature:String? = nil
    var extData:AnyObject? = nil
    
    init(data:AnyObject?) {
        lastTimestamp = Int64(NSDate().timeIntervalSince1970 * 1000)
        lastSignature = "\(lastTimestamp)"
        extData = data
    }
    
    init(data:AnyObject?, signature:String?) {
        lastTimestamp = Int64(NSDate().timeIntervalSince1970 * 1000)
        lastSignature = signature
        extData = data
    }
    
    func shouldUpdate(pre:ThemeSwitchData) -> Bool {
        return self === pre
    }
    
    class func shouldUpdate(pre:ThemeSwitchData?, lat:ThemeSwitchData?) -> Bool {
        if let pre = pre, lat = lat where pre === lat {
            return false
        } else if let a = pre?.lastSignature, b = lat?.lastSignature where a == b {
            return false
        }
        return true
    }
}

private class ThemeSwitchInternalConf {
    var dataSourceSuper = false  // true from superview/ parent controller, false get from config
    var switchRecursion = true
    let passDownConf:Bool

    init(passDown:Bool) {
        passDownConf = passDown
    }

    func updatePassDown(passDown:Bool) -> ThemeSwitchInternalConf {
        if passDownConf == passDown {
            return self
        }
        let conf = ThemeSwitchInternalConf(passDown:passDown)
        conf.dataSourceSuper = dataSourceSuper
        conf.switchRecursion = switchRecursion
        return conf
    }
}

private var kThemeLastSwitchKey: Void?
private var kThemeSwitchBlockKey: Void?
private var kThemeSwitchInternalConfigKey: Void?
public typealias SwitchThemeBlock = ((now:AnyObject?, pre:AnyObject?) -> Void)
private class ObjectWrapper<T> {
    var value :T?
    init(value:T?) {
        self.value = value
    }
}

public extension UIView {
    private var ch_themeSwitchData: ThemeSwitchData? {
        get {
            return objc_getAssociatedObject(self, &kThemeLastSwitchKey) as? ThemeSwitchData
        }
        set {
            objc_setAssociatedObject(self, &kThemeLastSwitchKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }

    private var ch_themeSwitchInternalConf: ThemeSwitchInternalConf {
        get {
            if let conf = objc_getAssociatedObject(self, &kThemeSwitchInternalConfigKey) as? ThemeSwitchInternalConf {
                return conf
            } else {
                let conf = ThemeSwitchInternalConf.init(passDown: true)
                objc_setAssociatedObject(self, &kThemeSwitchInternalConfigKey, conf, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
                return conf
            }
        }
        set {
            objc_setAssociatedObject(self, &kThemeSwitchInternalConfigKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }
    
    var ch_switchThemeBlock:SwitchThemeBlock? {
        get {
            if let data =  objc_getAssociatedObject(self, &kThemeSwitchBlockKey) as? ObjectWrapper<SwitchThemeBlock> {
                return data.value
            }
            return nil
        }
        set {
            objc_setAssociatedObject(self, &kThemeSwitchBlockKey, ObjectWrapper(value: newValue), .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }

    private func ch_switchThemeWrapper(data:ThemeSwitchData?) {
        let preData = ch_themeSwitchData
        guard ThemeSwitchData.shouldUpdate(preData, lat: data) else {
            return
        }
        guard ch_shouldSwitchTheme(data?.extData, pre: preData?.extData) else {
            return
        }
        // save switch data
        ch_themeSwitchData = data
        
        // call switch theme method
        ch_switchTheme(data?.extData, pre: preData?.extData)
        
        // call switch theme block
        ch_switchThemeBlock?(now:data?.extData, pre:preData?.extData)
    }
    
    /**
     Specifies whether the view should change theme.
     true if the status bar should be hidden or false if it should be shown
     
     - parameter now: the data you switch theme
     - parameter pre: the old data you switch theme
     
     - returns: true switch theme will happen, or false ignore switch theme
     */
    public func ch_shouldSwitchTheme(now:AnyObject?, pre: AnyObject?) -> Bool {
        return true
    }
    
    /**
     method switch theme/skin. default will call it's subview to switch theme
     
     - parameter now: the data you switch theme
     - parameter pre: the old data you switch theme
     */
    public func ch_switchTheme(now:AnyObject?, pre: AnyObject?) {
        // switch sub views
        if ch_themeSwitchInternalConf.switchRecursion {
            for sub in subviews {
                if ch_themeSwitchInternalConf.passDownConf {
                    sub.ch_themeSwitchInternalConf = ch_themeSwitchInternalConf
                }
                sub.ch_switchThemeWrapper(ch_themeSwitchData)
            }
        }
    }
    
    /**
     switch self and subviews theme
     
     - parameter data: data used to switch theme, will pass to ch_switchTheme(_:pre:) as first argument
     */
    public func ch_switchTheme(data:AnyObject?) {
        ch_themeSwitchInternalConf = ch_themeSwitchInternalConf.updatePassDown(true)
        ch_themeSwitchInternalConf.switchRecursion = true
        ch_switchThemeWrapper(ThemeSwitchData.init(data: data))
    }
    
    /**
     target switch data that will switch to
     
     - returns: data used to switch
     */
    private func ch_fetchSwitchThemeData() -> ThemeSwitchData? {
        if ch_themeSwitchInternalConf.dataSourceSuper {
            return superview?.ch_themeSwitchData
        }
        return ThemeSwitchMananger.instance.switchData
    }
    
    /**
     switch self and subviews theme, the data use depend on it config, act like ch_switchTheme(_:), but more efficient
     */
    public func ch_switchTheme() {
        ch_themeSwitchInternalConf = ch_themeSwitchInternalConf.updatePassDown(true)
        ch_themeSwitchInternalConf.switchRecursion = true
        ch_switchThemeWrapper(ch_fetchSwitchThemeData())
    }
    
    /**
     this method should use internal for auto switch config (for circleCall method)
     */
    private func ch_switchThemeSelfOnly() {
        ch_themeSwitchInternalConf = ch_themeSwitchInternalConf.updatePassDown(false)
        ch_themeSwitchInternalConf.switchRecursion = false
        ch_switchThemeWrapper(ch_fetchSwitchThemeData())
    }
}

public extension UIViewController {
    private var ch_themeSwitchData: ThemeSwitchData? {
        get {
            return objc_getAssociatedObject(self, &kThemeLastSwitchKey) as? ThemeSwitchData
        }
        set {
            objc_setAssociatedObject(self, &kThemeLastSwitchKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }

    private var ch_themeSwitchInternalConf: ThemeSwitchInternalConf {
        get {
            if let conf = objc_getAssociatedObject(self, &kThemeSwitchInternalConfigKey) as? ThemeSwitchInternalConf {
                return conf
            } else {
                let conf = ThemeSwitchInternalConf.init(passDown: true)
                objc_setAssociatedObject(self, &kThemeSwitchInternalConfigKey, conf, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
                return conf
            }
        }
        set {
            objc_setAssociatedObject(self, &kThemeSwitchInternalConfigKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }
    
    /// when theme switch happend, this block will run, default is nil
    /// Note: this block will run after ch_switchTheme(_:pre:) method
    var ch_switchThemeBlock:SwitchThemeBlock? {
        get {
            if let data =  objc_getAssociatedObject(self, &kThemeSwitchBlockKey) as? ObjectWrapper<SwitchThemeBlock> {
                return data.value
            }
            return nil
        }
        set {
            objc_setAssociatedObject(self, &kThemeSwitchBlockKey, ObjectWrapper(value: newValue), .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }

    private func ch_switchThemeWrapper(data:ThemeSwitchData?) {
        let preData = ch_themeSwitchData
        guard ThemeSwitchData.shouldUpdate(preData, lat: data) else {
            return
        }
        guard ch_shouldSwitchTheme(data?.extData, pre: preData?.extData) else {
            return
        }
        // save switch data
        ch_themeSwitchData = data
        
        // call switch theme method
        ch_switchTheme(data?.extData, pre: preData?.extData)
        
        // call switch theme block
        ch_switchThemeBlock?(now:data?.extData, pre:preData?.extData)
    }
    
    /**
     Specifies whether the view controller should change theme.
     true if the status bar should be hidden or false if it should be shown
     
     - parameter now: the data you switch theme
     - parameter pre: the old data you switch theme
     
     - returns: true switch theme will happen, or false ignore switch theme
     */
    public func ch_shouldSwitchTheme(now:AnyObject?, pre: AnyObject?) -> Bool {
        return true
    }
    
    /**
     method switch theme/skin. default will call it's childViewControllers to switch theme
     
     - parameter now: the data you switch theme
     - parameter pre: the old data you switch theme
     */
    public func ch_switchTheme(now:AnyObject?, pre: AnyObject?) {
        // switch sub view controller
        if ch_themeSwitchInternalConf.switchRecursion {
            for viewController in childViewControllers {
                if ch_themeSwitchInternalConf.passDownConf {
                    viewController.ch_themeSwitchInternalConf = ch_themeSwitchInternalConf
                }
                viewController.ch_switchThemeWrapper(ch_themeSwitchData)
            }
        }
    }
    
    /**
     switch self and childViewControllers's theme
     
     - parameter data: data used to switch theme, will pass to ch_switchTheme(_:pre:) as first argument
     */
    public func ch_switchTheme(data:AnyObject?) {
        ch_themeSwitchInternalConf = ch_themeSwitchInternalConf.updatePassDown(true)
        ch_themeSwitchInternalConf.switchRecursion = true
        ch_switchThemeWrapper(ThemeSwitchData.init(data: data))
    }
    
    /**
     target switch data that will switch to
     
     - returns: data used to switch
     */
    private func ch_fetchSwitchThemeData() -> ThemeSwitchData? {
        if ch_themeSwitchInternalConf.dataSourceSuper {
            return parentViewController?.ch_themeSwitchData
        }
        return ThemeSwitchMananger.instance.switchData
    }
    
    /**
     switch self and subviews theme, the data use depend on it config, act like ch_switchTheme(_:), but more efficient
     */
    public func ch_switchTheme() {
        ch_themeSwitchInternalConf = ch_themeSwitchInternalConf.updatePassDown(true)
        ch_themeSwitchInternalConf.switchRecursion = true
        ch_switchThemeWrapper(ch_fetchSwitchThemeData())
    }
    
    /**
     this method should use internal for auto switch config (for circleCall method)
     */
    private func ch_switchThemeSelfOnly() {
        ch_themeSwitchInternalConf = ch_themeSwitchInternalConf.updatePassDown(false)
        ch_themeSwitchInternalConf.switchRecursion = false
        ch_switchThemeWrapper(ch_fetchSwitchThemeData())
    }
}


extension NSObject {
    class func ch_exchangeInstanceMethod(originalSelector:Selector, swizzledSelector:Selector) {
        let originalMethod = class_getInstanceMethod(self, originalSelector)
        let swizzledMethod = class_getInstanceMethod(self, swizzledSelector)
        
        let didAddMethod = class_addMethod(self, originalSelector, method_getImplementation(swizzledMethod), method_getTypeEncoding(swizzledMethod))
        
        if didAddMethod {
            class_replaceMethod(self, swizzledSelector, method_getImplementation(originalMethod), method_getTypeEncoding(originalMethod))
        } else {
            method_exchangeImplementations(originalMethod, swizzledMethod)
        }
    }
}

class WeakRef<T: AnyObject> {
    weak var value : T?
    init (value: T) {
        self.value = value
    }
}

public class ThemeSwitchMananger {
    private var switchData = ThemeSwitchData.init(data: nil)
    
    public var themeData: AnyObject? {
        return switchData.extData
    }
    
    public func ch_switchTheme() {
        ThemeService.instance.switchTheme(themeData)
    }
    
    public static let instance = ThemeSwitchMananger()
}

public var kChThemeSwitchNotification = "kChThemeSwitchNotification"
private class ThemeService {
    private var viewControllers = [WeakRef<UIViewController>]()
    
    static let instance = ThemeService()
    
    func switchTheme(data: AnyObject?) {
        let switchData = ThemeSwitchData.init(data: data)
        ThemeSwitchMananger.instance.switchData = switchData
        let internalConf = ThemeSwitchInternalConf.init(passDown: true)
        internalConf.dataSourceSuper = ThemeServiceConfig.instance.viewAutoSwitchThemeDataSourceSuperView
        for window in UIApplication.sharedApplication().windows {
            // view
            window.ch_themeSwitchInternalConf = internalConf
            window.ch_switchThemeWrapper(switchData)

            // view controller
            window.rootViewController?.ch_themeSwitchInternalConf = internalConf
            window.rootViewController?.ch_switchThemeWrapper(switchData)
        }
        // enforce update view controller
        for weakRef in viewControllers {
            if let viewController = weakRef.value where nil == viewController.parentViewController {
                viewController.ch_themeSwitchInternalConf = internalConf
                viewController.ch_switchThemeWrapper(switchData)
            }
        }
        var userInfo:[String: AnyObject] = [:]
        if let data = data {
            userInfo["data"] = data
        }
        NSNotificationCenter.defaultCenter().postNotificationName(kChThemeSwitchNotification,
                                                                  object: nil,
                                                                  userInfo: userInfo)
    }
    
    private func registerViewController(controller: UIViewController) {
        var valideViewControllers = [WeakRef<UIViewController>]()
        for weakRef in viewControllers {
            if weakRef.value == controller {
                return
            }
            if let _ = weakRef.value {
                valideViewControllers.append(weakRef)
            }
        }
        valideViewControllers.append(WeakRef(value: controller))
        viewControllers = valideViewControllers
    }
}

public extension UIViewController {
    /**
     force view controller enable switch theme/skin
     Note: you call method if parentViewController is nil, normally you ignore it
     */
    func ch_registerViewController() {
        ThemeService.instance.registerViewController(self)
    }
}

public extension UIApplication {
    /**
     switch app theme
     
     - parameter data: data pass to view/viewcontroller's ch_switchTheme(_:pre:)
     */
    func ch_switchTheme(data: AnyObject? = nil) {
        ThemeService.instance.switchTheme(data)
    }
    /**
     switch app theme
     
     - parameter data: data pass to view/viewcontroller's ch_switchTheme(_:pre:)
     */
    class func ch_switchTheme(data: AnyObject? = nil) {
        ThemeService.instance.switchTheme(data)
    }
}

public class ThemeServiceConfig {
    // view config
    public var viewAutoSwitchThemeAfterAwakeFromNib = false
    public var viewAutoSwitchThemeAfterMovedToWindow = false
    // view controller config
    public var viewControllerAutoSwitchThemeAfterAwakeFromNib = false
    public var viewControllerAutoSwitchThemeWhenViewWillAppear = false
    
    
    // data source config
    public var viewAutoSwitchThemeDataSourceSuperView = false
    public var viewControllerAutoSwitchThemeDataSourceParent = false
    
    public static let instance = ThemeServiceConfig()
    
}

public extension UIView {
    private var ch_themeServiceConfig:ThemeServiceConfig {
        return ThemeServiceConfig.instance
    }
    
    func ch_awakeFromNib() {
        ch_awakeFromNib()
        if ch_themeServiceConfig.viewAutoSwitchThemeAfterAwakeFromNib {
            ch_switchTheme()
        }
    }
    
    func ch_didMoveToWindow() {
        ch_didMoveToWindow()
        if ch_themeServiceConfig.viewAutoSwitchThemeAfterMovedToWindow {
            ch_switchThemeSelfOnly()
        }
    }
    
    override class func initialize() {
        struct Static {
            static var token: dispatch_once_t = 0
        }
        
        dispatch_once(&Static.token) {
            ch_exchangeInstanceMethod(#selector(UIView.awakeFromNib), swizzledSelector: #selector(UIView.ch_awakeFromNib))
            ch_exchangeInstanceMethod(#selector(UIView.didMoveToWindow), swizzledSelector: #selector(UIView.ch_didMoveToWindow))
        }
    }
}

public extension UIViewController {
    private var ch_themeServiceConfig:ThemeServiceConfig {
        return ThemeServiceConfig.instance
    }
    
    func ch_awakeFromNib() {
        ch_awakeFromNib()
        if ch_themeServiceConfig.viewControllerAutoSwitchThemeAfterAwakeFromNib {
            ch_switchTheme()
        }
    }
    
    func ch_viewWillAppear(animated: Bool) {
        ch_viewWillAppear(animated)
        if ch_themeServiceConfig.viewControllerAutoSwitchThemeWhenViewWillAppear {
            ch_switchThemeSelfOnly()
        }
    }
    
    override class func initialize() {
        struct Static {
            static var token: dispatch_once_t = 0
        }
        
        dispatch_once(&Static.token) {
            ch_exchangeInstanceMethod(#selector(UIViewController.awakeFromNib), swizzledSelector: #selector(UIViewController.ch_awakeFromNib))
            ch_exchangeInstanceMethod(#selector(UIViewController.viewWillAppear(_:)), swizzledSelector: #selector(UIViewController.ch_viewWillAppear(_:)))
        }
    }
}

