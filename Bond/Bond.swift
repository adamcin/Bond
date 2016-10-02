//
//  Bond.swift
//  Bond
//
//  The MIT License (MIT)
//
//  Copyright (c) 2015 Srdan Rasic (@srdanrasic)
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.
//

// MARK: Helpers

import Foundation

open class BondBox<T> {
  weak var bond: Bond<T>?
  public init(_ b: Bond<T>) { bond = b }
}

open class DynamicBox<T> {
  weak var dynamic: Dynamic<T>?
  public init(_ d: Dynamic<T>) { dynamic = d }
}

// MARK: - Scalar Dynamic

// MARK: Bond

open class Bond<T> {
  public typealias Listener = (T) -> Void
  
  open var listener: Listener?
  open var bondedDynamics: [Dynamic<T>] = []
  open var bondedWeakDynamics: [DynamicBox<T>] = []
  
  public init() {
  }
  
  public init(_ listener: @escaping Listener) {
    self.listener = listener
  }
  
  open func bind(_ dynamic: Dynamic<T>) {
    bind(dynamic, fire: true, strongly: true)
  }
  
  open func bind(_ dynamic: Dynamic<T>, fire: Bool) {
    bind(dynamic, fire: fire, strongly: true)
  }
  
  open func bind(_ dynamic: Dynamic<T>, fire: Bool, strongly: Bool) {
    dynamic.bonds.append(BondBox(self))
    
    if strongly {
      self.bondedDynamics.append(dynamic)
    } else {
      self.bondedWeakDynamics.append(DynamicBox(dynamic))
    }
    
    if fire && dynamic.valid {
      self.listener?(dynamic.value)
    }
  }
  
  open func unbindAll() {
    let dynamics = bondedDynamics + bondedWeakDynamics.reduce([Dynamic<T>]()) { memo, value in
      if let dynamic = value.dynamic {
        return memo + [dynamic]
      } else {
        return memo
      }
    }
    
    for dynamic in dynamics {
      var bondsToKeep: [BondBox<T>] = []
      for bondBox in dynamic.bonds {
        if let bond = bondBox.bond {
          if bond !== self {
            bondsToKeep.append(bondBox)
          }
        }
      }
      dynamic.bonds = bondsToKeep
    }
    
    self.bondedDynamics.removeAll(keepingCapacity: true)
    self.bondedWeakDynamics.removeAll(keepingCapacity: true)
  }
}

// MARK: Dynamic

open class Dynamic<T> {
  
  fileprivate var dispatchInProgress: Bool = false
  
  internal var _value: T? {
    didSet {
      objc_sync_enter(self)
      if let value = _value {
        if !self.dispatchInProgress {
          dispatch(value)
        }
      }
      objc_sync_exit(self)
    }
  }
  
  open var value: T {
    set {
      _value = newValue
    }
    get {
      if _value == nil {
        fatalError("Dynamic has no value defined at the moment!")
      } else {
        return _value!
      }
    }
  }
  
  open var valid: Bool {
    get {
      return _value != nil
    }
  }
  
  fileprivate func dispatch(_ value: T) {
    // clear weak bonds
    self.bonds = self.bonds.filter {
      bondBox in bondBox.bond != nil
    }
    
    // lock
    self.dispatchInProgress = true
    
    // dispatch change notifications
    for bondBox in self.bonds {
      bondBox.bond?.listener?(value)
    }
    
    // unlock
    self.dispatchInProgress = false
  }
  
  open let valueBond = Bond<T>()
  open var bonds: [BondBox<T>] = []
  
  fileprivate init() {
    _value = nil
    valueBond.listener = { [unowned self] v in self.value = v }
  }

  public init(_ v: T) {
    _value = v
    valueBond.listener = { [unowned self] v in self.value = v }
  }
  
  open func bindTo(_ bond: Bond<T>) {
    bond.bind(self, fire: true, strongly: true)
  }
  
  open func bindTo(_ bond: Bond<T>, fire: Bool) {
    bond.bind(self, fire: fire, strongly: true)
  }
  
  open func bindTo(_ bond: Bond<T>, fire: Bool, strongly: Bool) {
    bond.bind(self, fire: fire, strongly: strongly)
  }
}

open class InternalDynamic<T>: Dynamic<T> {
  
  public override init() {
    super.init()
  }
  
  public override init(_ value: T) {
    super.init(value)
  }
  
  open var updatingFromSelf: Bool = false
  open var retainedObjects: [AnyObject] = []
  open func retain(_ object: AnyObject) {
    retainedObjects.append(object)
  }
}

// MARK: Protocols

public protocol Dynamical {
  associatedtype DynamicType
  var designatedDynamic: Dynamic<DynamicType> { get }
}

public protocol Bondable {
  associatedtype BondType
  var designatedBond: Bond<BondType> { get }
}

extension Dynamic: Bondable {
  public var designatedBond: Bond<T> {
    return self.valueBond
  }
}

// MARK: Functional additions

public extension Dynamic
{
  public func map<U>(_ f: @escaping (T) -> U) -> Dynamic<U> {
    return _map(self, f: f)
  }
  
  public func filter(_ f: @escaping (T) -> Bool) -> Dynamic<T> {
    return _filter(self, f: f)
  }
  
  public func filter(_ f: @escaping (T, T) -> Bool, _ v: T) -> Dynamic<T> {
    return _filter(self) { f($0, v) }
  }
  
  public func rewrite<U>(_ v:  U) -> Dynamic<U> {
    return _map(self) { _ in return v}
  }
  
  public func zip<U>(_ v: U) -> Dynamic<(T, U)> {
    return _map(self) { ($0, v) }
  }
  
  public func zip<U>(_ d: Dynamic<U>) -> Dynamic<(T, U)> {
    return reduce(self, dB: d) { ($0, $1) }
  }
  
  public func skip(_ count: Int) -> Dynamic<T> {
    return _skip(self, count: count)
  }
}


