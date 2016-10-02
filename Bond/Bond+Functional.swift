//
//  Bond+Functional.swift
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

// MARK: Map

public func map<T, U>(_ dynamic: Dynamic<T>, f: @escaping (T) -> U) -> Dynamic<U> {
  return _map(dynamic, f: f)
}

public func map<S: Dynamical, T, U>(_ dynamical: S, f: @escaping (T) -> U) -> Dynamic<U> where S.DynamicType == T {
  return _map(dynamical.designatedDynamic, f: f)
}

internal func _map<T, U>(_ dynamic: Dynamic<T>, f: @escaping (T) -> U) -> Dynamic<U> {
  
  let dyn = InternalDynamic<U>()
  
  if let value = dynamic._value {
    dyn.value = f(value)
  }
  
  let bond = Bond<T> { [unowned dyn] t in
    dyn.value = f(t)
  }
  
  dyn.retain(bond)
  dynamic.bindTo(bond, fire: false)
  
  return dyn
}

// MARK: Filter

public func filter<T>(_ dynamic: Dynamic<T>, f: @escaping (T) -> Bool) -> Dynamic<T> {
  return _filter(dynamic, f: f)
}

public func filter<T>(_ dynamic: Dynamic<T>, f: @escaping (T, T) -> Bool, v: T) -> Dynamic<T> {
  return _filter(dynamic) { f($0, v) }
}

public func filter<S: Dynamical, T>(_ dynamical: S, f: @escaping (T) -> Bool) -> Dynamic<T> where S.DynamicType == T {
  return _filter(dynamical.designatedDynamic, f: f)
}

internal func _filter<T>(_ dynamic: Dynamic<T>, f: @escaping (T) -> Bool) -> Dynamic<T> {
  
  let dyn = InternalDynamic<T>()
  
  if let value = dynamic._value {
    if f(value) {
      dyn.value = value
    }
  }
  
  let bond = Bond<T> { [unowned dyn] t in
    if f(t) {
      dyn.value = t
    }
  }
  
  dyn.retain(bond)
  dynamic.bindTo(bond, fire: false)
  
  return dyn
}

// MARK: Reduce

public func reduce<A, B, T>(_ dA: Dynamic<A>, dB: Dynamic<B>, f: @escaping (A, B) -> T) -> Dynamic<T> {
  return _reduce(dA, dB: dB, f: f)
}

public func reduce<A, B, C, T>(_ dA: Dynamic<A>, dB: Dynamic<B>, dC: Dynamic<C>, f: @escaping (A, B, C) -> T) -> Dynamic<T> {
  return _reduce(dA, dB: dB, dC: dC, f: f)
}

public func _reduce<A, B, T>(_ dA: Dynamic<A>, dB: Dynamic<B>, f: @escaping (A, B) -> T) -> Dynamic<T> {
  let dyn = InternalDynamic<T>()
  
  if let vA = dA._value, let vB = dB._value {
    dyn.value = f(vA, vB)
  }
  
  let bA = Bond<A> { [unowned dyn, weak dB] in
    if let vB = dB?._value {
      dyn.value = f($0, vB)
    }
  }
  
  let bB = Bond<B> { [unowned dyn, weak dA] in
    if let vA = dA?._value {
      dyn.value = f(vA, $0)
    }
  }
  
  dA.bindTo(bA, fire: false)
  dB.bindTo(bB, fire: false)
  
  dyn.retain(bA)
  dyn.retain(bB)
  
  return dyn
}

internal func _reduce<A, B, C, T>(_ dA: Dynamic<A>, dB: Dynamic<B>, dC: Dynamic<C>, f: @escaping (A, B, C) -> T) -> Dynamic<T> {
  let dyn = InternalDynamic<T>()
  
  if let vA = dA._value, let vB = dB._value, let vC = dC._value {
    dyn.value = f(vA, vB, vC)
  }
  
  let bA = Bond<A> { [unowned dyn, weak dB, weak dC] in
    if let vB = dB?._value, let vC = dC?._value { dyn.value = f($0, vB, vC) }
  }
  
  let bB = Bond<B> { [unowned dyn, weak dA, weak dC] in
    if let vA = dA?._value, let vC = dC?._value { dyn.value = f(vA, $0, vC) }
  }
  
  let bC = Bond<C> { [unowned dyn, weak dA, weak dB] in
    if let vA = dA?._value, let vB = dB?._value { dyn.value = f(vA, vB, $0) }
  }
  
  dA.bindTo(bA, fire: false)
  dB.bindTo(bB, fire: false)
  dC.bindTo(bC, fire: false)
  
  dyn.retain(bA)
  dyn.retain(bB)
  dyn.retain(bC)
  
  return dyn
}

// MARK: Rewrite

public func rewrite<T, U>(_ dynamic: Dynamic<T>, value: U) -> Dynamic<U> {
  return _map(dynamic) { _ in value }
}

// MARK: Zip

public func zip<T, U>(_ dynamic: Dynamic<T>, value: U) -> Dynamic<(T, U)> {
  return _map(dynamic) { ($0, value) }
}

public func zip<T, U>(_ d1: Dynamic<T>, d2: Dynamic<U>) -> Dynamic<(T, U)> {
  return reduce(d1, dB: d2) { ($0, $1) }
}

// MARK: Skip

public func _skip<T>(_ dynamic: Dynamic<T>, count: Int) -> Dynamic<T> {
  var count = count
  let dyn = InternalDynamic<T>()
  
  if count <= 0 {
    dyn.value = dynamic.value
  }
  
  let bond = Bond<T> { [unowned dyn] t in
    if count <= 0 {
      dyn.value = t
    } else {
      count -= 1
    }
  }
  
  dyn.retain(bond)
  dynamic.bindTo(bond, fire: false)
  
  return dyn
}

public func skip<T>(_ dynamic: Dynamic<T>, count: Int) -> Dynamic<T> {
  return _skip(dynamic, count: count)
}

// MARK: Any

public func any<T>(_ dynamics: [Dynamic<T>]) -> Dynamic<T> {  
  let dyn = InternalDynamic<T>()
  
  for dynamic in dynamics {
    let bond = Bond<T> { [unowned dynamic] in
      dyn.value = $0
    }
    dynamic.bindTo(bond, fire: false)
    dyn.retain(bond)
  }
  
  return dyn
}
