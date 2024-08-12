import Fluent
import Vapor

struct SequenceRequest: Content {
    var elementType: String
    var elementId: Int
}

struct ReorderRequest: Content {
    struct Element: Content {
        var elementId: Int
        var newSequence: Int
    }
    var elementType: String
    var elements: [Element]
}

struct VersionRequest: Content {
    struct NewVersionData: Content {
        var text: String
    }
    var elementType: String
    var elementId: Int
    var newVersionData: NewVersionData
}

final class SequenceController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        let sequence = routes.grouped("sequence")
        sequence.post(use: generateSequenceNumber)
        sequence.post("reorder", use: reorderElements)
        sequence.post("version", use: createVersion)
    }

    func generateSequenceNumber(req: Request) throws -> EventLoopFuture<SequenceElement> {
        let data = try req.content.decode(SequenceRequest.self)
        return SequenceElement.query(on: req.db)
            .filter(\. == data.elementType)
            .filter(\. == data.elementId)
            .count()
            .flatMap { count in
                let sequenceElement = SequenceElement(
                    elementType: data.elementType,
                    elementId: data.elementId,
                    sequenceNumber: count + 1,
                    versionNumber: 1
                )
                return sequenceElement.save(on: req.db).map { sequenceElement }
            }
    }

    func reorderElements(req: Request) throws -> EventLoopFuture<HTTPStatus> {
        let data = try req.content.decode(ReorderRequest.self)
        let updates = data.elements.map { element in
            SequenceElement.query(on: req.db)
                .filter(\. == data.elementType)
                .filter(\. == element.elementId)
                .set(\., to: element.newSequence)
                .update()
        }
        return updates.flatten(on: req.eventLoop).transform(to: .ok)
    }

    func createVersion(req: Request) throws -> EventLoopFuture<SequenceElement> {
        let data = try req.content.decode(VersionRequest.self)
        return SequenceElement.query(on: req.db)
            .filter(\. == data.elementType)
            .filter(\. == data.elementId)
            .first()
            .unwrap(or: Abort(.notFound))
            .flatMap { element in
                element.versionNumber += 1
                return element.save(on: req.db).map { element }
            }
    }
}
