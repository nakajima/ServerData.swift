//
//  PersistentStore.swift
//
//
//  Created by Pat Nakajima on 5/12/24.
//

import Foundation
import SQLKit

// Create a PersistentStore for your model to be able to save/load from it.
public struct PersistentStore<Model: StorableModel>: Sendable {
	public let model: Model.Type
	public let container: Container

	public init(for model: Model.Type, container: Container) {
		self.model = model
		self.container = container
	}

	public func setup() async {
		do {
			if try await container.tables().contains(Model._$table) {
				container.logger.info("already found \(Model._$table) table, skipping setup")
				return
			}

			try await Model.create(in: container.database)
		} catch {
			fatalError("Error setting up \(Model.self): \(error)")
		}
	}
}
