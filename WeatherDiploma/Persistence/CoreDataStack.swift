import CoreData
import Foundation

/// The container is used exclusively through private queue contexts and their perform blocks.
final class CoreDataStack: @unchecked Sendable {
    private let container: NSPersistentContainer
    private init(container: NSPersistentContainer) { self.container = container }

    static func make(storeURL: URL? = nil, inMemory: Bool = false) async throws -> CoreDataStack {
        guard let url = Bundle(for: CoreDataStack.self).url(forResource: "WeatherModel", withExtension: "momd"),
              let model = NSManagedObjectModel(contentsOf: url) else { throw WeatherError.invalidData }
        let container = NSPersistentContainer(name: "WeatherModel", managedObjectModel: model)
        let description = NSPersistentStoreDescription()
        if inMemory { description.type = NSInMemoryStoreType }
        else { description.url = storeURL ?? NSPersistentContainer.defaultDirectoryURL().appendingPathComponent("Weather.sqlite") }
        description.shouldAddStoreAsynchronously = true
        description.shouldMigrateStoreAutomatically = true
        description.shouldInferMappingModelAutomatically = true
        container.persistentStoreDescriptions = [description]
        let stack = CoreDataStack(container: container)
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            container.loadPersistentStores { _, error in
                if let error { continuation.resume(throwing: error) }
                else { continuation.resume() }
            }
        }
        return stack
    }

    func cities() async throws -> [City] {
        let context = container.newBackgroundContext()
        return try await context.perform {
            let request = NSFetchRequest<NSManagedObject>(entityName: "CityRecord")
            request.sortDescriptors = [NSSortDescriptor(key: "position", ascending: true)]
            return try context.fetch(request).map { record in
                guard let data = record.value(forKey: "payload") as? Data else { throw WeatherError.invalidData }
                return try JSONDecoder().decode(City.self, from: data)
            }
        }
    }

    func saveCities(_ cities: [City]) async throws {
        let context = container.newBackgroundContext()
        try await context.perform {
            for record in try context.fetch(NSFetchRequest<NSManagedObject>(entityName: "CityRecord")) { context.delete(record) }
            let validIDs = Set(cities.map(\.id))
            for record in try context.fetch(NSFetchRequest<NSManagedObject>(entityName: "ForecastRecord")) {
                if let id = record.value(forKey: "cityID") as? String, !validIDs.contains(id) { context.delete(record) }
            }
            for (position, city) in cities.enumerated() {
                let record = NSEntityDescription.insertNewObject(forEntityName: "CityRecord", into: context)
                record.setValue(city.id, forKey: "id")
                record.setValue(try JSONEncoder().encode(city), forKey: "payload")
                record.setValue(Double(position), forKey: "position")
            }
            try context.save()
        }
    }

    func forecast(for cityID: String) async throws -> Forecast? {
        let context = container.newBackgroundContext()
        return try await context.perform {
            let request = NSFetchRequest<NSManagedObject>(entityName: "ForecastRecord")
            request.predicate = NSPredicate(format: "cityID == %@", cityID)
            request.fetchLimit = 1
            guard let record = try context.fetch(request).first else { return nil }
            guard let data = record.value(forKey: "payload") as? Data else { throw WeatherError.invalidData }
            return try JSONDecoder().decode(Forecast.self, from: data)
        }
    }

    func save(_ forecast: Forecast, for cityID: String) async throws {
        let context = container.newBackgroundContext()
        try await context.perform {
            let request = NSFetchRequest<NSManagedObject>(entityName: "ForecastRecord")
            request.predicate = NSPredicate(format: "cityID == %@", cityID)
            let record = try context.fetch(request).first ?? NSEntityDescription.insertNewObject(forEntityName: "ForecastRecord", into: context)
            record.setValue(cityID, forKey: "cityID")
            record.setValue(try JSONEncoder().encode(forecast), forKey: "payload")
            record.setValue(forecast.fetchedAt, forKey: "fetchedAt")
            try context.save()
        }
    }
}
