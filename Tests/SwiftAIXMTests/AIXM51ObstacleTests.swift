import Foundation
import Testing

@testable import SwiftAIXM

@Suite
struct `AIXM 5.1 obstacles` {
  @Test
  func `reads a point obstacle with its top elevation and height`() throws {
    let (dataset, errors) = try Fixtures.dataset(Fixtures.britishObstacles)
    #expect(errors.isEmpty)

    let obstacle = try #require(dataset.obstacles.only)
    #expect(obstacle.name == "UK0229G149F")
    #expect(obstacle.type == .transmissionLine)
    #expect(obstacle.isLighted == false)

    let part = try #require(obstacle.parts.only)
    #expect(part.geometry == .point(Location(latitudeDeg: 51.0665889, longitudeDeg: -3.6193167)))
    #expect(part.topElevation == Measurement(value: 977, unit: .feet))
    #expect(part.height == Measurement(value: 351, unit: .feet))
  }

  @Test
  func `reads longitude-first positions in the CRS84 reference system`() throws {
    let (dataset, _) = try Fixtures.dataset(Fixtures.swissObstacles)
    let tree = try #require(dataset.obstacles.first { $0.name == "245NW30434" })
    let part = try #require(tree.parts.only)
    #expect(part.geometry == .point(Location(latitudeDeg: 46.97553642, longitudeDeg: 8.37464869)))
    #expect(part.topElevation == Measurement(value: 571.6, unit: .meters))
  }

  @Test
  func `reads each span of a line as a line part`() throws {
    let (dataset, _) = try Fixtures.dataset(Fixtures.swissObstacles)
    let line = try #require(dataset.obstacles.first { $0.name == "TL25003645" })
    #expect(line.parts.count > 1)
    #expect(
      line.parts.first?.geometry
        == .line([
          Location(latitudeDeg: 47.20249911, longitudeDeg: 8.79264352),
          Location(latitudeDeg: 47.2023736, longitudeDeg: 8.79354691)
        ])
    )
  }

  @Test
  func `reports a structure whose parts are all nil`() throws {
    let (dataset, errors) = try Fixtures.dataset(Fixtures.swissObstacles)
    #expect(!dataset.obstacles.contains { $0.name == "263BE20020" })

    let error = try #require(errors.only as? AIXMRecordError)
    guard case let .missingValue(feature, _, field) = error else {
      Issue.record("Expected a missing value, got \(error)")
      return
    }
    #expect(feature == "VerticalStructure")
    #expect(field == "part")
  }
}
